import Foundation
import Observation

/// Plays one level: no timers, no lives, unlimited retries.
@Observable
final class LevelPlayViewModel {
    let level: QuestLevel
    let chapter: QuestChapter
    let content: MoneyQuestContent

    private(set) var stepIndex = 0
    /// The option picked on the current step (nil until the player chooses).
    private(set) var chosen: Int?
    private(set) var stats: [ReadinessStat: Int] = [:]
    private(set) var budget = MoneyQuestConfig.monthlyBudget
    private(set) var correctAnswers = 0
    private(set) var reward: LevelReward?
    private(set) var isFinished = false
    var askNovaTopic: String?

    init(level: QuestLevel, chapter: QuestChapter, content: MoneyQuestContent = .shared) {
        self.level = level
        self.chapter = chapter
        self.content = content
        reset()
    }

    var step: QuestStep? { level.steps.indices.contains(stepIndex) ? level.steps[stepIndex] : nil }
    var progress: Double { Double(stepIndex + (chosen == nil ? 0 : 1)) / Double(max(1, level.steps.count)) }
    var chosenOption: QuestOption? { chosen.flatMap { step?.options.indices.contains($0) == true ? step?.options[$0] : nil } }

    func text(_ raw: String) -> String { content.resolve(raw) }

    func choose(_ index: Int) {
        guard chosen == nil, let step, step.options.indices.contains(index) else { return }
        chosen = index
        let option = step.options[index]
        if step.kind == .question, option.correct == true { correctAnswers += 1 }
        for (stat, change) in option.statChanges {
            stats[stat] = min(ReadinessStat.maxPoints, max(0, (stats[stat] ?? MoneyQuestConfig.startingStat) + change))
        }
        budget += Double(option.moneyChange)
    }

    func next(model: AppModel) async {
        guard chosen != nil else { return }
        if stepIndex + 1 < level.steps.count {
            stepIndex += 1
            chosen = nil
        } else {
            reward = await model.completeQuestLevel(level, in: chapter, correctAnswers: correctAnswers)
            isFinished = true
        }
    }

    func reset() {
        stepIndex = 0
        chosen = nil
        stats = Dictionary(uniqueKeysWithValues: ReadinessStat.allCases.map { ($0, MoneyQuestConfig.startingStat) })
        budget = MoneyQuestConfig.monthlyBudget
        correctAnswers = 0
        reward = nil
        isFinished = false
    }

    func askNova() {
        let topic = step?.topic ?? level.title
        askNovaTopic = "Can you explain \(topic) simply?"
    }
}
