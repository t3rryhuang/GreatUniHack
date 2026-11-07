import Foundation

/// One predicted spending behaviour for a day, for example "Lunch out, 72%, £12".
/// `agreedBy` lists the AI models that agreed (the original app's multi-LLM consensus).
struct PredictionItem: Identifiable, Hashable, Sendable {
    var id = UUID()
    let category: SpendingCategory
    let title: String
    let probability: Double
    let amount: Double
    var agreedBy: [String] = []
}

struct DayPrediction: Identifiable, Hashable, Sendable {
    var id: Date { date }
    let date: Date
    let items: [PredictionItem]

    var totalExpected: Double { items.reduce(0) { $0 + $1.amount * $1.probability } }
}

enum WeatherCondition: String, Sendable {
    case sunny, cloudy, rain, drizzle, wind, cold

    var symbol: String {
        switch self {
        case .sunny: "sun.max.fill"
        case .cloudy: "cloud.fill"
        case .rain: "cloud.rain.fill"
        case .drizzle: "cloud.drizzle.fill"
        case .wind: "wind"
        case .cold: "thermometer.snowflake"
        }
    }

    var label: String {
        switch self {
        case .sunny: "Sunny"
        case .cloudy: "Cloudy"
        case .rain: "Rain"
        case .drizzle: "Drizzle"
        case .wind: "Windy"
        case .cold: "Cold"
        }
    }
}

struct Weather: Hashable, Sendable {
    let city: String
    let temperatureC: Int
    let condition: WeatherCondition
    /// One line on how the weather tends to change spending.
    let spendingImpact: String
}

/// The daily briefing card and its read-aloud script.
struct MorningBriefing: Hashable, Sendable {
    let greeting: String
    let weather: Weather
    let topPrediction: PredictionItem?
    let expectedSpend: Double
    let nudge: String
    let script: String
}

/// A spending alert shown on Home and History.
struct SpendingAlert: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable { case spike, unusual, trend }
    var id = UUID()
    let kind: Kind
    let title: String
    let message: String
    let merchant: String?
    let amount: Double?
}

/// Weekly recap: how accurate last week's predictions were.
struct WeeklyRecap: Hashable, Sendable {
    let accuracy: Double
    let predictedTotal: Double
    let actualTotal: Double
    let highlights: [String]
    let topCategory: SpendingCategory?
}

struct RunwayResult: Hashable, Sendable {
    let months: Double
    let analysis: String
}
