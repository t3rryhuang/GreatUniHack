import Foundation

/// Money Quest progress kept on this device (`game.json`). Used by both containers.
final class LocalGameService: GameServicing {
    private let storeName = "game.json"
    private var state: GameProgress

    init() {
        state = LocalStore.load(GameProgress.self, from: storeName) ?? GameProgress()
    }

    func progress() async -> GameProgress { state }

    func completeLevel(_ levelID: String, in chapter: QuestChapter, correctAnswers: Int) async -> LevelReward {
        let (next, reward) = MoneyQuestRules.complete(levelID: levelID, chapter: chapter, correct: correctAnswers, progress: state)
        state = next
        persist()
        return reward
    }

    func resetDemo(stage: LifeStage) async {
        var fresh = GameProgress()
        if stage == .teen {
            // Two chapter 1 levels done on earlier days, so today's points start at 0.
            fresh.completedLevels = ["c1l1", "c1l2"]
            fresh.bestCorrect = ["c1l1": 2, "c1l2": 1]
            fresh.totalPoints = 75
            for (daysAgo, points) in [(2, 40), (4, 35)] {
                let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
                fresh.pointsByDay[MoneyQuestRules.dayKey(day)] = points
            }
        }
        state = fresh
        persist()
    }

    private func persist() { LocalStore.save(state, to: storeName) }
}
