import Foundation

/// Where the Nova backend lives. Override at runtime with the launch argument
/// `-NovaBackendURL http://localhost:8000` (Xcode > Scheme > Arguments), or turn
/// the backend off with `-NovaOffline` to use the on-device mocks only.
enum BackendConfig {
    static let defaultURL = URL(string: "https://nova-backend-silk.vercel.app")!

    static var baseURL: URL? {
        let defaults = UserDefaults.standard
        if ProcessInfo.processInfo.arguments.contains("-NovaOffline") { return nil }
        if let custom = defaults.string(forKey: "NovaBackendURL"), let url = URL(string: custom) { return url }
        return defaultURL
    }
}

/// Small JSON client for the FastAPI backend in `test-backend/`.
final class BackendClient: Sendable {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    struct APIError: Decodable { let detail: String }

    func data(_ method: String, _ path: String, body: (any Encodable)? = nil, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(body)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ServiceError.network("Can't reach Nova right now. Check your connection and try again.")
        }
        guard let http = response as? HTTPURLResponse else { throw ServiceError.network("Unexpected response.") }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? Self.decoder.decode(APIError.self, from: data))?.detail ?? "Server error (\(http.statusCode))."
            throw BackendError(status: http.statusCode, message: message)
        }
        return data
    }

    /// Uploads one file as multipart/form-data under the field name `file`.
    func upload<T: Decodable>(_ path: String, fileURL: URL, mimeType: String, as type: T.Type = T.self) async throws -> T {
        let boundary = "Nova-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, from: body)
        } catch {
            throw ServiceError.network("Can't reach Nova right now. Check your connection and try again.")
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = (try? Self.decoder.decode(APIError.self, from: data))?.detail ?? "Server error (\(status))."
            throw BackendError(status: status, message: message)
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    func send<T: Decodable>(_ method: String, _ path: String, body: (any Encodable)? = nil, headers: [String: String] = [:], as type: T.Type = T.self) async throws -> T {
        let data = try await data(method, path, body: body, headers: headers)
        return try Self.decoder.decode(T.self, from: data)
    }
}

struct BackendError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

// MARK: Wire formats shared by the insights and chat services

struct WireCategoryTotal: Codable {
    let category: String
    let amount: Double
    let share: Double
}

struct WireSummary: Codable {
    let totalSpent, avgDaily, avgMonthly, monthlyIncome, savings, savingsRate, runwayMonths: Double
    let spendingTrend: String
    let topCategories: [WireCategoryTotal]
    let dataRangeMonths: Double

    init(_ s: FinancialSummary) {
        totalSpent = s.totalSpent
        avgDaily = s.avgDaily
        avgMonthly = s.avgMonthly
        monthlyIncome = s.monthlyIncome
        savings = s.savings
        savingsRate = s.savingsRate
        runwayMonths = s.runwayMonths
        spendingTrend = s.spendingTrend.rawValue
        topCategories = s.topCategories.map { WireCategoryTotal(category: $0.category.rawValue, amount: $0.amount, share: $0.share) }
        dataRangeMonths = s.dataRangeMonths
    }
}
