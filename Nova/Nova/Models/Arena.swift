import Foundation

/// Arena game modes. Most Improved is new in Money Readiness.
enum ArenaMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case budgetGuardian = "budget_guardian"
    case viceStreak = "vice_streak"
    case savingsSprint = "savings_sprint"
    case mostImproved = "most_improved"

    /// Modes offered in Teen mode (no Vice Streak).
    static let teenModes: [ArenaMode] = [.mostImproved, .budgetGuardian, .savingsSprint]

    static func available(for stage: LifeStage) -> [ArenaMode] {
        stage == .teen ? teenModes : allCases
    }

    /// Modes that use a spending target.
    var usesTarget: Bool { self == .budgetGuardian || self == .savingsSprint }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .budgetGuardian: "Budget Guardian"
        case .viceStreak: "Vice Streak"
        case .savingsSprint: "Savings Sprint"
        case .mostImproved: "Most Improved"
        }
    }

    var rule: String {
        switch self {
        case .budgetGuardian: "Stay under your spending target. The lowest spender under budget wins."
        case .viceStreak: "Avoid your vice category. The last one standing wins."
        case .savingsSprint: "First to reach the savings target wins."
        case .mostImproved: "Cut your spending compared with your own previous period. The biggest % drop wins, so everyone starts level."
        }
    }

    var symbol: String {
        switch self {
        case .budgetGuardian: "shield.lefthalf.filled"
        case .viceStreak: "flame.fill"
        case .savingsSprint: "flag.checkered"
        case .mostImproved: "chart.line.downtrend.xyaxis"
        }
    }

    var targetLabel: String {
        switch self {
        case .budgetGuardian: "Spending limit"
        case .viceStreak: "Allowed spend"
        case .savingsSprint: "Savings target"
        case .mostImproved: "Compared with"
        }
    }
}

enum ArenaStatus: String, Codable, Sendable {
    case pending, active, completed
}

struct ArenaMember: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var isCurrentUser: Bool = false
    var currentSpend: Double = 0
    var currentSavings: Double = 0
    var isEliminated: Bool = false
    /// When the member went over budget or broke their streak. Used for tie-breaks.
    var exceededAt: Date?
    /// When the member reached the savings target (Savings Sprint).
    var targetReachedAt: Date?
    var lastSyncedAt: Date?
    /// Most Improved: spending in the previous period of the same length.
    /// Optional, so arenas saved by older builds (and older backends) still load.
    var baselineSpend: Double?

    /// Most Improved: share of spending cut versus the baseline (0.25 = 25% less). Nil without a baseline.
    var reduction: Double? {
        guard let baselineSpend, baselineSpend > 0 else { return nil }
        return (baselineSpend - currentSpend) / baselineSpend
    }

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

/// A savings challenge between friends. Stakes are in pounds and are held in a
/// NatWest savings account (this replaces the original Solana escrow).
struct Arena: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var mode: ArenaMode
    var targetAmount: Double
    var stakeAmount: Double
    var viceCategory: SpendingCategory?
    var startDate: Date
    var endDate: Date
    var joinCode: String
    var status: ArenaStatus
    var members: [ArenaMember]
    var winnerID: UUID?

    var prizePot: Double { stakeAmount * Double(members.count) }
    /// No money changes hands: the winner earns points and badges.
    var isMoneyFree: Bool { stakeAmount <= 0 }

    var daysLeft: Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: endDate).day ?? 0)
    }

    var progress: Double {
        let total = endDate.timeIntervalSince(startDate)
        guard total > 0 else { return 1 }
        return min(1, max(0, Date.now.timeIntervalSince(startDate) / total))
    }
}

/// Result of settling an arena: who won and the pay-out into their savings account.
struct ArenaSettlement: Hashable, Sendable {
    let arenaID: UUID
    let winner: ArenaMember?
    let standings: [ArenaMember]
    let payout: Double
    let reference: String
    let settledAt: Date
}

enum ArenaRules {
    /// Ranks members for a mode. Ported from `determineWinner` in the original app.
    static func standings(for arena: Arena) -> [ArenaMember] {
        let target = arena.targetAmount
        let far = Date.distantFuture
        let active = arena.members.filter { !$0.isEliminated }
        let ranked = active.sorted { a, b in
            switch arena.mode {
            case .budgetGuardian:
                let aUnder = a.currentSpend <= target, bUnder = b.currentSpend <= target
                if aUnder != bUnder { return aUnder }
                if !aUnder { return (a.exceededAt ?? far) > (b.exceededAt ?? far) }
                return a.currentSpend < b.currentSpend
            case .viceStreak:
                let aClean = a.currentSpend <= target, bClean = b.currentSpend <= target
                if aClean != bClean { return aClean }
                if !aClean { return (a.exceededAt ?? far) > (b.exceededAt ?? far) }
                return a.currentSpend < b.currentSpend
            case .savingsSprint:
                let aDone = a.currentSavings >= target, bDone = b.currentSavings >= target
                if aDone != bDone { return aDone }
                if aDone { return (a.targetReachedAt ?? far) < (b.targetReachedAt ?? far) }
                return a.currentSavings > b.currentSavings
            case .mostImproved:
                return mostImprovedOrder(a, b)
            }
        }
        return ranked + arena.members.filter(\.isEliminated)
    }

    /// Most Improved order (same as `_standings` in test-backend/arena.py):
    /// members with a baseline first, then the biggest % reduction, then the
    /// lower current spend, then name.
    static func mostImprovedOrder(_ a: ArenaMember, _ b: ArenaMember) -> Bool {
        let aHas = a.reduction != nil, bHas = b.reduction != nil
        if aHas != bHas { return aHas }
        let ar = a.reduction ?? 0, br = b.reduction ?? 0
        if ar != br { return ar > br }
        if a.currentSpend != b.currentSpend { return a.currentSpend < b.currentSpend }
        return a.name < b.name
    }

    /// The caller's own progress for an arena, from their transactions.
    /// Used by both the on-device and the backend arena services.
    static func progress(for arena: Arena, transactions: [Transaction], now: Date = .now) -> (spend: Double, savings: Double, baseline: Double?) {
        let end = min(arena.endDate, now)
        let inPeriod = transactions.filter { $0.date >= arena.startDate && $0.date <= end }
        func everyday(_ list: [Transaction]) -> Double {
            list.filter { $0.isExpense && ![.rent, .transfer, .utilities].contains($0.category) }.reduce(0) { $0 + $1.spend }
        }
        switch arena.mode {
        case .budgetGuardian:
            return (everyday(inPeriod), 0, nil)
        case .viceStreak:
            let vice = arena.viceCategory ?? .coffee
            return (inPeriod.filter { $0.category == vice && $0.isExpense }.reduce(0) { $0 + $1.spend }, 0, nil)
        case .savingsSprint:
            return (0, inPeriod.filter { $0.category == .transfer && $0.isExpense }.reduce(0) { $0 + $1.spend }, nil)
        case .mostImproved:
            // Compare like with like: the same number of days just before the arena started.
            let elapsed = max(0, end.timeIntervalSince(arena.startDate))
            let baseStart = arena.startDate.addingTimeInterval(-elapsed)
            let before = transactions.filter { $0.date >= baseStart && $0.date < arena.startDate }
            return (everyday(inPeriod), 0, elapsed > 0 ? everyday(before) : nil)
        }
    }

    static func winner(of arena: Arena) -> ArenaMember? { standings(for: arena).first }

    /// An arena can be settled once it has ended, or early when someone finishes a Savings Sprint.
    static func canSettle(_ arena: Arena) -> Bool {
        guard arena.status != .completed, arena.members.count >= 2 else { return false }
        if arena.endDate <= .now { return true }
        return arena.mode == .savingsSprint && arena.members.contains { $0.currentSavings >= arena.targetAmount }
    }

    static func blockReason(_ arena: Arena) -> String? {
        if arena.status == .completed { return "This arena has already been settled." }
        if arena.members.count < 2 { return "You need at least 2 members to settle." }
        if !canSettle(arena) { return "Settlement opens when the arena ends in \(arena.daysLeft) days." }
        return nil
    }

    /// Whether a member is close to losing (80% of the target used).
    static func isAtRisk(_ member: ArenaMember, in arena: Arena) -> Bool {
        (arena.mode == .budgetGuardian || arena.mode == .viceStreak) && member.currentSpend >= arena.targetAmount * 0.8
    }

    /// Whether going over the target knocks a member out of first place (not for Savings Sprint or Most Improved).
    static func hasSpendingLimit(_ mode: ArenaMode) -> Bool {
        mode == .budgetGuardian || mode == .viceStreak
    }
}
