import Foundation
import Observation

/// What a parent would see: totals, progress and safety alerts. Never individual transactions.
@Observable
final class ParentPreviewViewModel {
    struct Alert: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let message: String
    }

    /// The last 4 weeks of everyday spending, oldest first.
    func weeklyTotals(model: AppModel) -> [(label: String, total: Double)] {
        let totals = Array((model.readiness?.weeklyTotals ?? []).suffix(4))
        return totals.enumerated().map { index, total in
            let weeksAgo = totals.count - 1 - index
            return (weeksAgo == 0 ? "This week" : weeksAgo == 1 ? "Last week" : "\(weeksAgo) weeks ago", total)
        }
    }

    func alerts(model: AppModel, now: Date = .now) -> [Alert] {
        var result: [Alert] = []
        let weekly = model.readiness?.weeklyTotals ?? []
        if let thisWeek = weekly.last, weekly.count > 1 {
            let usual = weekly.dropLast().reduce(0, +) / Double(weekly.count - 1)
            if usual > 0, thisWeek > usual * 1.4 {
                result.append(Alert(title: "Spending is higher than usual",
                                    message: "This week is about \(((thisWeek / usual) - 1).percent) above the usual week."))
            }
        }
        let overdue = model.family.scheduledPayments(now: now).filter {
            $0.paid == nil && now > $0.due.addingTimeInterval(ReadinessRules.graceDays * 86_400)
        }
        if !overdue.isEmpty {
            result.append(Alert(title: "A family payment is overdue", message: "\(overdue.count) payment\(overdue.count == 1 ? " is" : "s are") past the due date."))
        }
        return result
    }
}
