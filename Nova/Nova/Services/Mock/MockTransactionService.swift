import Foundation

/// Mock transaction store, saved to disk. Parses JSON and CSV statements locally;
/// PDF parsing is a backend job (`/parse-pdf`), so the mock returns demo data for PDFs.
final class MockTransactionService: TransactionServicing {
    private let storeName = "transactions.json"
    private var transactions: [Transaction]

    init() {
        transactions = LocalStore.load([Transaction].self, from: storeName) ?? []
    }

    func fetchTransactions() async throws -> [Transaction] {
        await simulateLatency(300)
        return transactions.sorted { $0.date > $1.date }
    }

    func loadDemoData(stage: LifeStage) async throws -> [Transaction] {
        await simulateLatency(900)
        let manual = transactions.filter(\.isManual)
        // Leave out demo transactions later today, so today's quest starts fresh.
        let demo = (stage == .teen ? MockDataFactory.teenTransactions() : MockDataFactory.demoTransactions())
            .filter { $0.date <= .now }
        transactions = (demo + manual).sorted { $0.date > $1.date }
        persist()
        return transactions
    }

    func importStatement(_ data: Data, type: ImportFileType) async throws -> [Transaction] {
        await simulateLatency(1_000)
        let parsed: [Transaction]
        switch type {
        case .json: parsed = try StatementParser.parseJSON(data)
        case .csv: parsed = try StatementParser.parseCSV(data)
        case .pdf: parsed = MockDataFactory.demoTransactions(months: 3, seed: UInt64(data.count))
        }
        guard !parsed.isEmpty else { throw ServiceError.unreadableFile }
        // Merge, skipping exact duplicates.
        let existing = Set(transactions.map { "\($0.date.timeIntervalSince1970)|\($0.description)|\($0.amount)" })
        let fresh = parsed.filter { !existing.contains("\($0.date.timeIntervalSince1970)|\($0.description)|\($0.amount)") }
        transactions = (transactions + fresh).sorted { $0.date > $1.date }
        persist()
        return transactions
    }

    func add(_ transaction: Transaction) async throws {
        await simulateLatency(250)
        transactions.insert(transaction, at: 0)
        transactions.sort { $0.date > $1.date }
        persist()
    }

    func delete(id: UUID) async throws {
        transactions.removeAll { $0.id == id }
        persist()
    }

    func clearAll() async throws {
        await simulateLatency(300)
        transactions = []
        LocalStore.remove(storeName)
    }

    private func persist() { LocalStore.save(transactions, to: storeName) }
}

/// Parses bank statements in the JSON and CSV formats the original app accepted.
enum StatementParser {
    private struct Row: Decodable {
        let date: String
        let description: String
        let amount: Double
        let category: String?
    }

    private struct Wrapper: Decodable {
        let transactions: [Row]
    }

    static func parseJSON(_ data: Data) throws -> [Transaction] {
        let rows: [Row]
        if let list = try? JSONDecoder().decode([Row].self, from: data) {
            rows = list
        } else if let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data) {
            rows = wrapper.transactions
        } else {
            throw ServiceError.unreadableFile
        }
        return rows.compactMap { row in
            guard let date = parseDate(row.date) else { return nil }
            let category = row.category.flatMap { SpendingCategory(rawValue: $0.capitalized) }
                ?? SpendingCategory.categorise(row.description)
            return Transaction(date: date, description: row.description, amount: row.amount, category: category)
        }
    }

    /// Expects a header row containing `date`, `description` and `amount` columns (any order).
    static func parseCSV(_ data: Data) throws -> [Transaction] {
        guard let text = String(data: data, encoding: .utf8) else { throw ServiceError.unreadableFile }
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let header = lines.first else { throw ServiceError.unreadableFile }
        let columns = header.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let dateIndex = columns.firstIndex(where: { $0.contains("date") }),
              let descIndex = columns.firstIndex(where: { $0.contains("desc") || $0.contains("merchant") || $0.contains("name") }),
              let amountIndex = columns.firstIndex(where: { $0.contains("amount") || $0.contains("value") })
        else { throw ServiceError.unreadableFile }

        return lines.dropFirst().compactMap { line in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"")) }
            guard fields.count > max(dateIndex, descIndex, amountIndex),
                  let date = parseDate(fields[dateIndex]),
                  let amount = Double(fields[amountIndex].replacingOccurrences(of: "£", with: ""))
            else { return nil }
            let description = fields[descIndex]
            return Transaction(date: date, description: description, amount: amount, category: SpendingCategory.categorise(description))
        }
    }

    static func parseDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        for format in ["yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy", "yyyy-MM-dd HH:mm:ss"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_GB")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}
