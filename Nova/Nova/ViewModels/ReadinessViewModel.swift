import Foundation
import Observation

@Observable
final class ReadinessViewModel {
    /// The stat whose explanation sheet is open.
    var selectedStat: ReadinessStat?
    /// Weekly limit being edited in the Balance sheet.
    var limitDraft: Double = 0

    func open(_ stat: ReadinessStat, model: AppModel) {
        if stat == .balance { limitDraft = (model.readiness?.weeklyLimit ?? 50).rounded() }
        selectedStat = stat
    }

    func saveLimit(model: AppModel) async {
        await model.setWeeklyLimit(max(5, limitDraft))
    }

    func useAverageLimit(model: AppModel) async {
        await model.setWeeklyLimit(nil)
        limitDraft = (model.readiness?.weeklyLimit ?? limitDraft).rounded()
    }

    /// Points still needed for the next rank, or nil at Diamond.
    func pointsToNextRank(_ score: ReadinessScore) -> (ReadinessRank, Int)? {
        guard let next = score.rank.next else { return nil }
        return (next, next.floor - score.total)
    }
}
