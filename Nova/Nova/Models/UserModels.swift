import Foundation

struct UserProfile: Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var email: String
    var bank: Bank = .natwest
    var memberSince: Date = .now
    /// Optional, so profiles saved by older builds still load. Drives `stage`.
    var dateOfBirth: Date?

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

/// Banks offered on the connect screen: NatWest Group brands first, then other UK banks.
enum Bank: String, Codable, CaseIterable, Identifiable, Sendable {
    case natwest = "NatWest"
    case rbs = "Royal Bank of Scotland"
    case ulster = "Ulster Bank"
    case barclays = "Barclays"
    case lloyds = "Lloyds"
    case hsbc = "HSBC UK"
    case santander = "Santander UK"

    var id: String { rawValue }
    var isNatWestGroup: Bool { self == .natwest || self == .rbs || self == .ulster }
}

/// A NatWest savings account. Replaces the original Solana wallet: arena stakes
/// are moved here and prize pots are paid back here.
struct SavingsAccount: Codable, Hashable, Sendable {
    var name: String
    var sortCode: String
    var accountNumber: String
    var balance: Double
    var interestRate: Double
    var activity: [SavingsActivity]

    var maskedNumber: String { "•••• " + accountNumber.suffix(4) }
}

struct SavingsActivity: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var date: Date
    var title: String
    var amount: Double
    var reference: String
}

/// Subscription tier. Pro unlocks the same features as the original Pro tier.
enum Plan: String, Codable, Sendable {
    case free, pro
}

enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case fullHistory, weeklyRecap, unlimitedWhatIfs, voiceBriefing, aiChat, arenaCreate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullHistory: "Full spending history"
        case .weeklyRecap: "Weekly recap"
        case .unlimitedWhatIfs: "Unlimited what-ifs"
        case .voiceBriefing: "Voice briefings"
        case .aiChat: "Ask Nova chat"
        case .arenaCreate: "Create arenas"
        }
    }

    var detail: String {
        switch self {
        case .fullHistory: "See month and year views, not just this week."
        case .weeklyRecap: "Check how accurate last week's predictions were."
        case .unlimitedWhatIfs: "Ask as many what-if questions as you like."
        case .voiceBriefing: "Have your morning briefing read aloud."
        case .aiChat: "Chat with Nova about your money, by text or voice."
        case .arenaCreate: "Start your own savings challenges with friends."
        }
    }
}

struct ChatMessage: Identifiable, Hashable, Sendable {
    enum Role: Sendable { case user, assistant }
    var id = UUID()
    let role: Role
    let text: String
    var date: Date = .now
}

/// Answer to a what-if question in the Simulator.
struct WhatIfResult: Identifiable, Hashable, Sendable {
    var id = UUID()
    let question: String
    let outcome: String
    let amount: Double
    let period: String
    let isPositive: Bool
    let beforeLabel: String
    let beforeValue: Double
    let afterLabel: String
    let afterValue: Double
    let confidence: Int
    let details: String
}

enum ImportFileType: String, Sendable {
    case json, csv, pdf
}
