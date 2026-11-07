import Foundation
import Observation

@Observable
final class SimulatorViewModel {
    static let freeQuestionLimit = 1
    static let suggestions = ["Quit my job", "Cut eating out by 50%", "Move somewhere cheaper",
                              "Make coffee at home", "Cycle to work", "Save £200 a month", "Cancel my subscriptions"]

    var question = ""
    /// Runway slider: how much monthly spending is cut, 0–50%.
    var spendingCut = 0.0
    private(set) var results: [WhatIfResult] = []
    private(set) var expanded: Set<UUID> = []
    private(set) var tips: [String] = []
    private(set) var isThinking = false
    private(set) var questionsUsed = 0
    private var tipsVersion = -1

    func runwayMonths(summary: FinancialSummary) -> Double {
        let burn = summary.avgMonthly * (1 - spendingCut)
        return burn > 0 ? summary.savings / burn : 0
    }

    func useSuggestion(_ text: String, model: AppModel) {
        guard canAsk(model: model) else { return }
        question = "What if I \(text.prefix(1).lowercased() + text.dropFirst())?"
    }

    func ask(model: AppModel) async {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, canAsk(model: model) else { return }
        isThinking = true
        defer { isThinking = false }
        do {
            let result = try await model.services.insights.whatIf(text, summary: model.summary, transactions: model.transactions)
            results.insert(result, at: 0)
            expanded.insert(result.id)
            question = ""
            if !model.isPro { questionsUsed += 1 }
            await model.recordWisdom(.whatIf)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    func toggle(_ id: UUID) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    func loadTips(model: AppModel) async {
        guard tipsVersion != model.dataVersion, model.hasData else { return }
        tips = (try? await model.services.insights.budgetTips(summary: model.summary)) ?? []
        tipsVersion = model.dataVersion
    }

    private func canAsk(model: AppModel) -> Bool {
        if !model.isPro && questionsUsed >= Self.freeQuestionLimit {
            return model.require(.unlimitedWhatIfs)
        }
        return true
    }
}
