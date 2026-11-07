import Foundation

/// AI insights from the backend: live Manchester weather, the 3-model week-ahead
/// consensus (Claude, Gemini, GPT via Runware), runway, budget tips and what-ifs.
/// Anything that fails falls back to the on-device calculations in `MockInsightsService`,
/// so the app keeps working offline.
final class RemoteInsightsService: MockInsightsService {
    private let client: BackendClient
    private var weekCache: (key: Int, days: [DayPrediction], at: Date)?

    init(client: BackendClient) {
        self.client = client
        super.init()
    }

    override func weather() async throws -> Weather {
        struct Wire: Decodable { let city: String; let temperatureC: Int; let condition: String; let spendingImpact: String }
        do {
            let w: Wire = try await client.send("GET", "nova/weather")
            return Weather(city: w.city, temperatureC: w.temperatureC,
                           condition: WeatherCondition(rawValue: w.condition) ?? .cloudy, spendingImpact: w.spendingImpact)
        } catch {
            return try await super.weather()
        }
    }

    override func weekAhead(from transactions: [Transaction]) async throws -> [DayPrediction] {
        // Three models take a few seconds; reuse the result for the same data for 30 minutes.
        let key = transactions.count &* 31 &+ Int(transactions.map(\.amount).reduce(0, +) * 100)
        if let cache = weekCache, cache.key == key, Date.now.timeIntervalSince(cache.at) < 1_800,
           Calendar.current.isDateInToday(cache.days.first?.date ?? .distantPast) {
            return cache.days
        }
        struct Item: Decodable { let category: String; let title: String; let probability: Double; let amount: Double; let agreedBy: [String] }
        struct Day: Decodable { let date: String; let items: [Item] }
        struct Response: Decodable { let days: [Day] }
        struct Txn: Encodable { let date: Date; let description: String; let amount: Double; let category: String }
        struct Body: Encodable { let transactions: [Txn] }

        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: .now) ?? .distantPast
        let body = Body(transactions: transactions.filter { $0.date >= cutoff && $0.isExpense }
            .map { Txn(date: $0.date, description: $0.description, amount: $0.amount, category: $0.category.rawValue) })
        guard !body.transactions.isEmpty else { return try await super.weekAhead(from: transactions) }
        do {
            let response: Response = try await client.send("POST", "nova/week-ahead", body: body)
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            let days = response.days.compactMap { day -> DayPrediction? in
                guard let date = formatter.date(from: day.date) else { return nil }
                return DayPrediction(date: date, items: day.items.map {
                    PredictionItem(category: SpendingCategory(rawValue: $0.category) ?? .other, title: $0.title,
                                   probability: $0.probability, amount: $0.amount, agreedBy: $0.agreedBy)
                })
            }
            guard !days.isEmpty else { return try await super.weekAhead(from: transactions) }
            weekCache = (key, days, .now)
            return days
        } catch {
            return try await super.weekAhead(from: transactions)
        }
    }

    override func runway(summary: FinancialSummary) async throws -> RunwayResult {
        struct Wire: Decodable { let months: Double; let analysis: String }
        do {
            let r: Wire = try await client.send("POST", "nova/runway", body: ["summary": WireSummary(summary)])
            return RunwayResult(months: r.months, analysis: r.analysis)
        } catch {
            return try await super.runway(summary: summary)
        }
    }

    override func budgetTips(summary: FinancialSummary) async throws -> [String] {
        struct Wire: Decodable { let tips: [String] }
        do {
            let r: Wire = try await client.send("POST", "nova/budget-tips", body: ["summary": WireSummary(summary)])
            return r.tips.isEmpty ? try await super.budgetTips(summary: summary) : r.tips
        } catch {
            return try await super.budgetTips(summary: summary)
        }
    }

    override func whatIf(_ question: String, summary: FinancialSummary, transactions: [Transaction]) async throws -> WhatIfResult {
        struct Body: Encodable { let question: String; let summary: WireSummary }
        struct Wire: Decodable {
            let outcome: String; let amount: Double; let period: String; let isPositive: Bool
            let beforeLabel: String; let beforeValue: Double; let afterLabel: String; let afterValue: Double
            let confidence: Int; let details: String
        }
        do {
            let r: Wire = try await client.send("POST", "nova/what-if", body: Body(question: question, summary: WireSummary(summary)))
            return WhatIfResult(question: question, outcome: r.outcome, amount: r.amount, period: r.period, isPositive: r.isPositive,
                                beforeLabel: r.beforeLabel, beforeValue: r.beforeValue, afterLabel: r.afterLabel,
                                afterValue: r.afterValue, confidence: r.confidence, details: r.details)
        } catch {
            return try await super.whatIf(question, summary: summary, transactions: transactions)
        }
    }
}
