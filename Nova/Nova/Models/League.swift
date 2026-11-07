import Foundation

// Friend and school leagues for Teen mode: ranked by points and improvement only.
// Entries show rank, badges and character, never money.

struct LeagueEntry: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let rank: ReadinessRank
    let badges: Int
    /// Money Quest points in the last 7 days.
    let weeklyPoints: Int
    /// Readiness Score change over the last 30 days.
    let improvement: Int
    var isCurrentUser = false
}

struct League: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case friends, school
        var id: String { rawValue }
        var title: String { self == .friends ? "Friends" : "School" }
    }
    var id: Kind { kind }
    let kind: Kind
    let name: String
    let entries: [LeagueEntry]
}

enum LeagueRules {
    /// Points first, then improvement, then name. Money never comes into it.
    static func ranked(_ entries: [LeagueEntry]) -> [LeagueEntry] {
        entries.sorted {
            if $0.weeklyPoints != $1.weeklyPoints { return $0.weeklyPoints > $1.weeklyPoints }
            if $0.improvement != $1.improvement { return $0.improvement > $1.improvement }
            return $0.name < $1.name
        }
    }

    static func weeklyPoints(_ game: GameProgress, now: Date = .now) -> Int {
        (0..<7).reduce(0) { total, daysAgo in
            let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return total + (game.pointsByDay[MoneyQuestRules.dayKey(day)] ?? 0)
        }
    }
}

/// Rank perks unlock with rank, which comes from habits, never from a balance.
struct RankPerk: Identifiable, Hashable, Sendable {
    var id: String { title }
    let rank: ReadinessRank
    let title: String
    let symbol: String

    static let all: [RankPerk] = [
        RankPerk(rank: .bronze, title: "Your Readiness character", symbol: "figure.walk"),
        RankPerk(rank: .silver, title: "Piggy Bank colour themes", symbol: "paintpalette.fill"),
        RankPerk(rank: .gold, title: "Character badge on your league card", symbol: "medal.fill"),
        RankPerk(rank: .platinum, title: "Early access to new Money Quest chapters", symbol: "gamecontroller.fill"),
        RankPerk(rank: .diamond, title: "Diamond edition Readiness Report", symbol: "diamond.fill")
    ]
}
