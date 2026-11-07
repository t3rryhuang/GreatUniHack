import Foundation
import Observation

@Observable
final class PiggyBankViewModel {
    /// Bumps on every shake to drive the animation.
    private(set) var shakeCount = 0
    private(set) var lastTier = 0
    /// After a shake (or a tap), the saved amount and % are shown.
    var isRevealed = false
    var amountVisible = false
    var depositAmount = 5.0
    private(set) var isWorking = false
    var message: String?
    var errorMessage: String?

    // Goal form
    var goalName = ""
    var goalAmount = 25.0
    var hasTargetDate = false
    var targetDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now

    // Promise form
    var promiseAmount = 2.0
    var promiseWeekday = 6

    @ObservationIgnored private let sound = CoinSoundPlayer()

    static let quickAmounts: [Double] = [1, 2, 5, 10]

    func progress(model: AppModel) -> Double {
        guard let piggy = model.piggy else { return 0 }
        return PiggyRules.progress(piggy, scale: model.hardshipScale)
    }

    func shake(model: AppModel, soundOn: Bool, hapticsOn: Bool) {
        let tier = PiggyRules.tier(progress: progress(model: model))
        lastTier = tier
        if soundOn { sound.play(tier: tier) }
        if hapticsOn { PiggyHaptics.play(tier: tier) }
        shakeCount += 1
        isRevealed = true
    }

    func stopSound() { sound.stop() }

    func prepareGoalForm(model: AppModel) {
        if let piggy = model.piggy {
            goalName = piggy.goalName
            goalAmount = piggy.goalAmount
            hasTargetDate = piggy.targetDate != nil
            targetDate = piggy.targetDate ?? targetDate
        } else {
            goalName = ""
            goalAmount = PiggyRules.suggestedGoal(monthlyIncome: model.summary.monthlyIncome)
        }
        if let promise = model.piggy?.promise {
            promiseAmount = promise.amount
            promiseWeekday = promise.weekday
        }
    }

    func saveGoal(model: AppModel) async {
        await model.setPiggyGoal(name: goalName.isEmpty ? "My goal" : goalName, amount: goalAmount, targetDate: hasTargetDate ? targetDate : nil)
    }

    func deposit(model: AppModel, rewardsOn: Bool) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let bonus = try await model.addToPiggy(depositAmount, rewardsOn: rewardsOn)
            message = bonus > 0 ? "Goal reached! A \(bonus.gbp) matched bonus (example) was added." : "\(depositAmount.gbp) added. Shake to hear it."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func keepPromise(model: AppModel, rewardsOn: Bool) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await model.keepPromise(rewardsOn: rewardsOn)
            message = "Promise kept. That counts towards Reliability."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePromise(model: AppModel, on: Bool) async {
        await model.setPromise(amount: on ? promiseAmount : nil, weekday: promiseWeekday)
    }
}
