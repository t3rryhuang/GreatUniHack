import Foundation

/// Arena game modes, unchanged from the original app.
enum ArenaMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case budgetGuardian = "budget_guardian"
    case viceStreak = "vice_streak"
    case savingsSprint = "savings_sprint"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .budgetGuardian: "Budget Guardian"
        case .viceStreak: "Vice Streak"
        case .savingsSprint: "Savings Sprint"
        }
    }

    var rule: String {
        switch self {
        case .budgetGuardian: "Stay under your spending target. The lowest spender under budget wins."
        case .viceStreak: "Avoid your vice category. The last one standing wins."
        case .savingsSprint: "First to reach the savings target wins the prize pot."
        }
    }

    var symbol: String {
        switch self {
        case .budgetGuardian: "shield.lefthalf.filled"
        case .viceStreak: "flame.fill"
        case .savingsSprint: "flag.checkered"
        }
    }

    var targetLabel: String {
        switch self {
        case .budgetGuardian: "Spending limit"
        case .viceStreak: "Allowed spend"
        case .savingsSprint: "Savings target"
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
            }
        }
        return ranked + arena.members.filter(\.isEliminated)
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
        arena.mode != .savingsSprint && member.currentSpend >= arena.targetAmount * 0.8
    }
}
