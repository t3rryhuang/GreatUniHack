import Foundation

// Piggy Bank: a Teen-mode savings pot inside the NatWest savings account.
// Everything is relative to the teen's own goal, never the £ amount.

/// Demo rewards. An example for the pitch, not a real NatWest offer.
enum RewardsConfig {
    /// Matched-savings bonus when a teen reaches their own goal: 50% of the first £20 saved.
    static let matchRate = 0.5
    static let matchOnFirst = 20.0
    static var maxBonus: Double { matchRate * matchOnFirst }
    static let label = "Example reward for the pitch, not a real NatWest offer."
}

struct PiggyDeposit: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var date: Date
    var amount: Double
    /// Part of the weekly "promise to myself".
    var isPromise = false
}

/// A weekly transfer into the piggy bank, from £1. Each on-time transfer counts
/// towards Reliability like a bill, for teens with nobody to borrow from.
struct PromiseToMyself: Codable, Hashable, Sendable {
    var amount: Double
    /// 1 = Sunday ... 7 = Saturday.
    var weekday: Int
    var startDate: Date
    var payments: [FamilyPayment] = []

    /// Weekly due dates from the start to next week, with any payment made.
    func cycles(now: Date = .now, calendar: Calendar = .current) -> [FamilyPayment] {
        var result: [FamilyPayment] = []
        var date = calendar.nextDate(after: calendar.startOfDay(for: startDate).addingTimeInterval(-1),
                                     matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime) ?? startDate
        let limit = now.addingTimeInterval(7 * 86_400)
        while date <= limit {
            let paid = payments.first { calendar.isDate($0.due, inSameDayAs: date) }
            result.append(FamilyPayment(id: paid?.id ?? UUID(), due: date, amount: amount, paid: paid?.paid))
            guard let next = calendar.date(byAdding: .day, value: 7, to: date) else { break }
            date = next
        }
        return result
    }

    func nextDue(now: Date = .now) -> FamilyPayment? {
        cycles(now: now).filter { $0.paid == nil }.min { $0.due < $1.due }
    }
}

struct PiggyBank: Codable, Hashable, Sendable {
    var goalName: String
    var goalAmount: Double
    var targetDate: Date?
    var saved: Double = 0
    var deposits: [PiggyDeposit] = []
    var promise: PromiseToMyself?
    var goalReachedAt: Date?
    var bonusPaid: Double = 0
}

enum PiggyRules {
    /// A goal sized to the teen: 10% of a month's own income, rounded, at least £5.
    static func suggestedGoal(monthlyIncome: Double) -> Double {
        max(5, (monthlyIncome * 0.1).rounded())
    }

    /// Share of the goal saved (0...1). `scale` eases the goal during hardship.
    static func progress(_ piggy: PiggyBank, scale: Double = 1) -> Double {
        let goal = effectiveGoal(piggy, scale: scale)
        return goal > 0 ? min(1, piggy.saved / goal) : 0
    }

    static func effectiveGoal(_ piggy: PiggyBank, scale: Double = 1) -> Double {
        (piggy.goalAmount * min(1, max(0.3, scale)) * 100).rounded() / 100
    }

    /// Sound, haptics and animation level from progress to the teen's OWN goal:
    /// 0 = under 25%, 1 = 25-50%, 2 = 50-75%, 3 = 75-100%, 4 = goal reached.
    static func tier(progress: Double) -> Int {
        switch progress {
        case 1...: 4
        case 0.75..<1: 3
        case 0.5..<0.75: 2
        case 0.25..<0.5: 1
        default: 0
        }
    }

    /// Fixed matched-savings bonus for reaching your own goal (see RewardsConfig).
    static func matchBonus(saved: Double) -> Double {
        (min(saved, RewardsConfig.matchOnFirst) * RewardsConfig.matchRate * 100).rounded() / 100
    }

    /// Consecutive calendar months, up to this one, with at least one saving deposit (any amount).
    static func savingStreakMonths(_ deposits: [Date], now: Date, calendar: Calendar = .current) -> Int {
        let months = Set(deposits.map { ReadinessRules.monthKey($0, calendar: calendar) })
        var streak = 0
        var cursor = now
        // This month counts once there's a deposit; otherwise start from last month.
        if !months.contains(ReadinessRules.monthKey(cursor, calendar: calendar)) {
            cursor = calendar.date(byAdding: .month, value: -1, to: cursor) ?? cursor
        }
        while months.contains(ReadinessRules.monthKey(cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .month, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
