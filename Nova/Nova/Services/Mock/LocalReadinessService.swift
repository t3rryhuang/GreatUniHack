import Foundation

/// Readiness Score kept on this device (`readiness.json`). Used by both the mock
/// and the live container: the score is computed from data the phone already has.
final class LocalReadinessService: ReadinessServicing {
    private let storeName = "readiness.json"
    private var state: ReadinessProgress

    init() {
        state = LocalStore.load(ReadinessProgress.self, from: storeName) ?? ReadinessProgress()
    }

    func progress() async -> ReadinessProgress { state }

    func evaluate(_ input: ReadinessInput) async -> ReadinessSnapshot {
        let result = ReadinessRules.score(input, progress: state)
        let today = Calendar.current.startOfDay(for: input.now)
        if state.seedHistory {
            state.history = Self.backfill(to: result.0.total, today: today)
            state.seedHistory = false
        }
        state.history.removeAll { $0.date == today }
        state.history.append(DailyScore(date: today, total: result.0.total))
        state.history = Array(state.history.sorted { $0.date < $1.date }.suffix(90))
        persist()

        let monthAgo = Calendar.current.date(byAdding: .day, value: -29, to: today) ?? today
        return ReadinessSnapshot(
            score: result.0,
            history: state.history.filter { $0.date >= monthAgo },
            bills: result.bills,
            payments: result.payments,
            weeklyTotals: result.weekly,
            weeklyLimit: result.limit,
            streak: state.streak,
            longestStreak: state.longestStreak,
            shieldsLeft: 1
        )
    }

    func record(_ event: WisdomEvent) async -> ReadinessProgress {
        switch event {
        case .whatIf: state.whatIfs += 1
        case .lesson: state.lessons += 1
        case .sandbox:
            if !state.sandboxDone { state.lessons += 1 }
            state.sandboxDone = true
        }
        persist()
        return state
    }

    func setWeeklyLimit(_ limit: Double?) async -> ReadinessProgress {
        state.weeklyLimit = limit
        persist()
        return state
    }

    func resetDemo(stage: LifeStage) async {
        var fresh = ReadinessProgress()
        switch stage {
        case .teen:
            fresh.streak = 23
            fresh.longestStreak = 23
            fresh.questsCompleted = 23
            fresh.whatIfs = 1
        case .adult:
            fresh.streak = 9
            fresh.longestStreak = 31
            fresh.questsCompleted = 40
            fresh.whatIfs = 2
        }
        fresh.seedHistory = true
        state = fresh
        persist()
    }

    /// A gentle 30-day climb ending at today's score, so the demo chart has a story.
    private static func backfill(to total: Int, today: Date) -> [DailyScore] {
        var rng = MockDataFactory.SeededGenerator(seed: UInt64(total) &+ 99)
        return (1...29).reversed().compactMap { daysAgo in
            guard let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let wobble = Int.random(in: -6...6, using: &rng)
            return DailyScore(date: date, total: max(0, total - daysAgo * 2 - 8 + wobble))
        }
    }

    private func persist() { LocalStore.save(state, to: storeName) }
}
