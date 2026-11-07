import Observation
import SwiftUI

@Observable
final class HomeViewModel {
    private(set) var weekAhead: [DayPrediction] = []
    private(set) var briefing: MorningBriefing?
    private(set) var alerts: [SpendingAlert] = []
    private(set) var isLoading = false
    var selectedDay: Date?

    private var loadedVersion = -1

    var selectedPrediction: DayPrediction? {
        weekAhead.first { $0.date == selectedDay } ?? weekAhead.first
    }

    func load(model: AppModel, force: Bool = false) async {
        guard force || loadedVersion != model.dataVersion else { return }
        guard model.hasData else {
            weekAhead = []; briefing = nil; alerts = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        let insights = model.services.insights
        let transactions = model.transactions
        do {
            async let week = insights.weekAhead(from: transactions)
            async let brief = insights.briefing(from: transactions, name: model.user?.firstName ?? "there")
            async let found = insights.alerts(from: transactions)
            weekAhead = try await week
            briefing = try await brief
            alerts = try await found
            if selectedDay == nil { selectedDay = weekAhead.first?.date }
            loadedVersion = model.dataVersion
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}
