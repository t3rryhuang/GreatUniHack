import SwiftUI

/// Spending categories. Each one has an SF Symbol and a chart colour from the
/// NatWest data-visualisation palette.
enum SpendingCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case coffee = "Coffee"
    case groceries = "Groceries"
    case dining = "Dining"
    case drinks = "Drinks"
    case transport = "Transport"
    case shopping = "Shopping"
    case subscriptions = "Subscriptions"
    case utilities = "Utilities"
    case entertainment = "Entertainment"
    case rent = "Rent"
    case healthcare = "Healthcare"
    case education = "Education"
    case transfer = "Transfer"
    case income = "Income"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .coffee: "cup.and.saucer.fill"
        case .groceries: "cart.fill"
        case .dining: "fork.knife"
        case .drinks: "wineglass.fill"
        case .transport: "tram.fill"
        case .shopping: "bag.fill"
        case .subscriptions: "play.rectangle.fill"
        case .utilities: "bolt.fill"
        case .entertainment: "ticket.fill"
        case .rent: "house.fill"
        case .healthcare: "cross.case.fill"
        case .education: "book.fill"
        case .transfer: "arrow.left.arrow.right"
        case .income: "sterlingsign.circle.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .coffee, .education: NovaColor.chartTangerine
        case .groceries, .healthcare: NovaColor.chartBroccoli
        case .dining: NovaColor.chartWatermelon
        case .drinks, .entertainment: NovaColor.chartAubergine
        case .transport, .utilities: NovaColor.chartBlueberry
        case .shopping: NovaColor.chartYolk
        case .subscriptions, .rent: NovaColor.chartChampion
        case .transfer, .income, .other: NovaColor.chartGrey
        }
    }

    /// Categories counted as "vices" in the Vice Streak arena.
    static let vices: [SpendingCategory] = [.coffee, .dining, .drinks, .shopping, .entertainment]

    /// Categories a user can pick when logging an expense by hand.
    static let expenseCategories: [SpendingCategory] = allCases.filter { $0 != .income && $0 != .transfer }

    /// Keyword-based categorisation, ported from the original app and updated for UK merchants.
    static func categorise(_ description: String) -> SpendingCategory {
        let text = description.lowercased()
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }

        if has("coffee", "costa", "pret", "starbucks", "caffe nero", "gail", "cafe") { return .coffee }
        if has("uber", "bolt", "taxi", "metrolink", "tram", "bee network", "bus", "rail", "trainline", "lime") { return .transport }
        if has("tesco", "sainsbury", "waitrose", "lidl", "aldi", "asda", "co-op", "m&s food", "ocado", "grocer") { return .groceries }
        if has("netflix", "spotify", "disney", "subscription", "apple.com", "youtube", "prime", "gym") { return .subscriptions }
        if has("pub", "bar", "brewdog", "wetherspoon", "beer", "wine", "drinks") { return .drinks }
        if has("restaurant", "nando", "dishoom", "wagamama", "deliveroo", "uber eats", "just eat", "lunch", "dinner", "food") { return .dining }
        if has("rent", "landlord", "letting") { return .rent }
        if has("octopus", "british gas", "edf", "united utilities", "council tax", "ee ", "vodafone", "o2", "bt ", "utility") { return .utilities }
        if has("amazon", "asos", "zara", "primark", "john lewis", "h&m", "uniqlo", "shop", "store") { return .shopping }
        if has("cinema", "odeon", "vue", "ticket", "eventbrite", "steam", "playstation") { return .entertainment }
        if has("boots", "pharmacy", "dentist", "superdrug", "gp ") { return .healthcare }
        if has("udemy", "coursera", "waterstones", "book") { return .education }
        if has("salary", "payroll", "wages", "income", "freelance") { return .income }
        if has("transfer", "sent to", "received from") { return .transfer }
        return .other
    }
}

/// One account transaction. Negative amounts are spending, positive amounts are income.
struct Transaction: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var date: Date
    var description: String
    var amount: Double
    var category: SpendingCategory
    var isManual: Bool = false

    var isExpense: Bool { amount < 0 }
    var spend: Double { isExpense ? -amount : 0 }
}
