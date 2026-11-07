import Foundation
import Observation

@Observable
final class HistoryViewModel {
    enum Period: String, CaseIterable, Identifiable {
        case week = "Week", month = "Month", year = "Year"
        var id: String { rawValue }
    }

    var period: Period = .week
    var searchText = ""

    /// Expenses (and income) inside the selected period.
    func transactions(in all: [Transaction]) -> [Transaction] {
        let start = startDate
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return all.filter { $0.date >= start }
            .filter { query.isEmpty || $0.description.lowercased().contains(query) || $0.category.rawValue.lowercased().contains(query) }
    }

    func categoryTotals(in all: [Transaction]) -> [CategoryTotal] {
        let expenses = transactions(in: all).filter { $0.isExpense && $0.category != .transfer }
        let total = expenses.reduce(0) { $0 + $1.spend }
        var byCategory: [SpendingCategory: Double] = [:]
        for t in expenses { byCategory[t.category, default: 0] += t.spend }
        return byCategory
            .map { CategoryTotal(category: $0.key, amount: $0.value, share: total > 0 ? $0.value / total : 0) }
            .sorted { $0.amount > $1.amount }
    }

    func totalSpent(in all: [Transaction]) -> Double {
        transactions(in: all).filter { $0.isExpense && $0.category != .transfer }.reduce(0) { $0 + $1.spend }
    }

    /// Transactions grouped by day, newest first, for the list.
    func groupedByDay(_ all: [Transaction]) -> [(day: Date, items: [Transaction])] {
        let grouped = Dictionary(grouping: transactions(in: all)) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).prefix(60).map { ($0, grouped[$0] ?? []) }
    }

    private var startDate: Date {
        let calendar = Calendar.current
        return switch period {
        case .week: calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        case .month: calendar.date(byAdding: .month, value: -1, to: .now) ?? .now
        case .year: calendar.date(byAdding: .year, value: -1, to: .now) ?? .now
        }
    }
}
