import Foundation
import Observation

@Observable
final class InsightsViewModel {
    struct TrajectoryPoint: Identifiable, Hashable {
        var id: String { "\(month.timeIntervalSince1970)-\(isProjection)" }
        let month: Date
        let amount: Double
        let isProjection: Bool
    }

    struct WeekComparison: Identifiable, Hashable {
        var id: SpendingCategory { category }
        let category: SpendingCategory
        let thisWeek: Double
        let lastWeek: Double
    }

    private(set) var runway: RunwayResult?
    private(set) var recap: WeeklyRecap?
    private(set) var isLoading = false
    private(set) var trajectory: [TrajectoryPoint] = []
    private(set) var weekComparison: [WeekComparison] = []
    private var loadedVersion = -1

    func load(model: AppModel, force: Bool = false) async {
        guard force || loadedVersion != model.dataVersion, model.hasData else { return }
        isLoading = true
        defer { isLoading = false }
        buildTrajectory(model.summary)
        buildWeekComparison(model.transactions)
        do {
            async let runwayResult = model.services.insights.runway(summary: model.summary)
            async let recapResult = model.services.insights.weeklyRecap(from: model.transactions)
            runway = try await runwayResult
            recap = try await recapResult
            loadedVersion = model.dataVersion
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    /// Last 6 months of actual spend plus a 3-month projection from the recent average.
    private func buildTrajectory(_ summary: FinancialSummary) {
        let recent = Array(summary.monthlySnapshots.suffix(6))
        var points = recent.map { TrajectoryPoint(month: $0.month, amount: $0.totalSpent, isProjection: false) }
        guard let last = recent.last else { trajectory = []; return }
        let average = recent.map(\.totalSpent).reduce(0, +) / Double(recent.count)
        let growth: Double = switch summary.spendingTrend {
        case .increasing: 1.03
        case .decreasing: 0.97
        case .stable: 1.0
        }
        // The projection starts at the last actual point so the dashed line joins up.
        points.append(TrajectoryPoint(month: last.month, amount: last.totalSpent, isProjection: true))
        var value = average
        for offset in 1...3 {
            value *= growth
            if let month = Calendar.current.date(byAdding: .month, value: offset, to: last.month) {
                points.append(TrajectoryPoint(month: month, amount: value, isProjection: true))
            }
        }
        trajectory = points
    }

    private func buildWeekComparison(_ transactions: [Transaction]) {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now),
              let lastStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start),
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastStart) else { return }
        var current: [SpendingCategory: Double] = [:]
        var previous: [SpendingCategory: Double] = [:]
        let tracked = SpendingCategory.vices + [.transport, .groceries]
        for t in transactions where t.isExpense && tracked.contains(t.category) {
            if thisWeek.contains(t.date) { current[t.category, default: 0] += t.spend }
            if lastWeek.contains(t.date) { previous[t.category, default: 0] += t.spend }
        }
        let categories = Set(current.keys).union(previous.keys)
        weekComparison = categories
            .map { WeekComparison(category: $0, thisWeek: current[$0] ?? 0, lastWeek: previous[$0] ?? 0) }
            .sorted { $0.thisWeek + $0.lastWeek > $1.thisWeek + $1.lastWeek }
            .prefix(5)
            .map { $0 }
    }
}
