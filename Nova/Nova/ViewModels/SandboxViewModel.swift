import Foundation
import Observation

/// "Borrow £200, repay over 3 months": an on-device what-if for teens. Nothing is borrowed.
@Observable
final class SandboxViewModel {
    var amount = 200.0
    var months = 3
    /// Example interest rate (APR %). 0 is like a family loan.
    var apr = 0.0

    var monthly: Double { ReadinessRules.monthlyPayment(amount: amount, months: months, apr: apr) }
    var totalRepaid: Double { monthly * Double(months) }
    var interest: Double { max(0, totalRepaid - amount) }

    func outcome(model: AppModel) -> (now: Int, allOnTime: Int, oneMissed: Int) {
        ReadinessRules.sandboxOutcome(payments: model.readiness?.payments ?? [], months: months, now: .now)
    }

    func finish(model: AppModel) async {
        await model.recordWisdom(.sandbox)
    }
}
