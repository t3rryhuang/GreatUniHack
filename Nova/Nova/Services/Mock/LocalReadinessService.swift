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
        state = ReadinessRules.settleQuests(state, transactions: input.transactions, now: input.now)
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
            shieldsLeft: ReadinessRules.shieldsLeft(state, now: input.now),
            quest: state.quests.first { $0.date == today },
            boss: ReadinessRules.weeklyBoss(bills: result.bills, payments: result.payments, now: input.now),
            recentShield: state.lastShieldEvent.flatMap { input.now.timeIntervalSince($0.date) < 7 * 86_400 ? $0 : nil }
        )
    }

    func todaysQuest(predictions: [PredictionItem]) async -> DailyQuest? {
        let today = Calendar.current.startOfDay(for: .now)
        if let existing = state.quests.first(where: { $0.date == today }) { return existing }
        guard let quest = ReadinessRules.makeQuest(from: predictions, on: today) else { return nil }
        state.quests.append(quest)
        state.quests = Array(state.quests.suffix(60))
        persist()
        return quest
    }

    func completeTodaysQuest() async -> ReadinessProgress {
        let today = Calendar.current.startOfDay(for: .now)
        if let index = state.quests.firstIndex(where: { $0.date == today }), state.quests[index].status == .pending {
            state.quests[index].status = .completed
            state.streak += 1
            state.questsCompleted += 1
            state.longestStreak = max(state.longestStreak, state.streak)
            persist()
        }
        return state
    }

    func record(_ event: WisdomEvent) async -> ReadinessProgress {
        switch event {
        case .whatIf: state.whatIfs += 1
        case .lesson: state.lessons += 1
        case .sandbox:
            state.sandboxDone = true
        case .moneyQuestLevel:
            state.moneyQuestLevels += 1
        }
        persist()
        return state
    }

    func setWeeklyLimit(_ limit: Double?) async -> ReadinessProgress {
        state.weeklyLimit = limit
        persist()
        return state
    }

    func setVotingChecked(_ done: Bool) async -> ReadinessProgress {
        state.votingChecked = done
        persist()
        return state
    }

    func markReportPreviewed() async -> ReadinessProgress {
        state.reportPreviewed = true
        persist()
        return state
    }

    func resetDemo(stage: LifeStage) async {
        var fresh = ReadinessProgress()
        switch stage {
        case .teen:
            // The shield saved a 21-day streak two days ago; completing today's quest makes it 23.
            fresh.streak = 22
            fresh.longestStreak = 22
            fresh.questsCompleted = 22
            fresh.whatIfs = 1
            fresh.moneyQuestLevels = 2
            let shieldDay = Calendar.current.date(byAdding: .day, value: -2, to: Calendar.current.startOfDay(for: .now)) ?? .now
            fresh.shieldMonths = [ReadinessRules.monthKey(shieldDay)]
            fresh.lastShieldEvent = ShieldEvent(date: shieldDay, savedStreak: 21)
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
