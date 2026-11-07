import Foundation

struct MonthlySnapshot: Identifiable, Hashable, Sendable {
    var id: Date { month }
    let month: Date
    let totalSpent: Double
    let totalIncome: Double
    var netSavings: Double { totalIncome - totalSpent }
}

struct CategoryTotal: Identifiable, Hashable, Sendable {
    var id: SpendingCategory { category }
    let category: SpendingCategory
    let amount: Double
    let share: Double
}

enum SpendingTrend: String, Sendable {
    case increasing, decreasing, stable
}

/// Seasonal monthly averages (UK meteorological seasons).
struct SeasonalSpend: Hashable, Sendable {
    var winter: Double
    var spring: Double
    var summer: Double
    var autumn: Double
}

/// Aggregate figures derived from the transaction list. Mirrors the original
/// `TransactionSummary` so the real backend can return the same shape later.
struct FinancialSummary: Hashable, Sendable {
    var totalSpent: Double
    var avgDaily: Double
    var avgMonthly: Double
    var monthlyIncome: Double
    /// Money in the user's savings account.
    var savings: Double
    var savingsRate: Double
    var runwayMonths: Double
    var spendingTrend: SpendingTrend
    var topCategories: [CategoryTotal]
    var monthlySnapshots: [MonthlySnapshot]
    var seasonal: SeasonalSpend
    var dataRangeMonths: Double

    static let empty = FinancialSummary(
        totalSpent: 0, avgDaily: 0, avgMonthly: 0, monthlyIncome: 0, savings: 0,
        savingsRate: 0, runwayMonths: 0, spendingTrend: .stable, topCategories: [],
        monthlySnapshots: [], seasonal: SeasonalSpend(winter: 0, spring: 0, summer: 0, autumn: 0),
        dataRangeMonths: 0
    )
}

extension FinancialSummary {
    /// Builds a summary from raw transactions. Ported from `calculateSummaryFromTransactions`.
    static func make(from transactions: [Transaction], savingsBalance: Double, calendar: Calendar = .current) -> FinancialSummary {
        guard let first = transactions.map(\.date).min(), let last = transactions.map(\.date).max() else {
            return .empty
        }
        let expenses = transactions.filter(\.isExpense)
        let totalSpent = expenses.reduce(0) { $0 + $1.spend }
        let totalIncome = transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }

        let days = max(1, calendar.dateComponents([.day], from: first, to: last).day ?? 1)
        let months = max(1, Double(days) / 30.44)

        var byCategory: [SpendingCategory: Double] = [:]
        for t in expenses { byCategory[t.category, default: 0] += t.spend }
        let top = byCategory
            .sorted { $0.value > $1.value }
            .map { CategoryTotal(category: $0.key, amount: $0.value, share: totalSpent > 0 ? $0.value / totalSpent : 0) }

        var byMonth: [Date: (spent: Double, income: Double)] = [:]
        for t in transactions {
            let start = calendar.dateInterval(of: .month, for: t.date)?.start ?? t.date
            var entry = byMonth[start, default: (0, 0)]
            if t.isExpense { entry.spent += t.spend } else { entry.income += t.amount }
            byMonth[start] = entry
        }
        let snapshots = byMonth
            .sorted { $0.key < $1.key }
            .map { MonthlySnapshot(month: $0.key, totalSpent: $0.value.spent, totalIncome: $0.value.income) }

        // Seasonal averages per month.
        var seasonTotals: [Int: [Double]] = [:]
        for snap in snapshots {
            let month = calendar.component(.month, from: snap.month)
            let season: Int = switch month {
            case 12, 1, 2: 0
            case 3, 4, 5: 1
            case 6, 7, 8: 2
            default: 3
            }
            seasonTotals[season, default: []].append(snap.totalSpent)
        }
        let avgMonthly = totalSpent / months
        func average(_ season: Int) -> Double {
            guard let values = seasonTotals[season], !values.isEmpty else { return avgMonthly }
            return values.reduce(0, +) / Double(values.count)
        }

        var trend = SpendingTrend.stable
        let amounts = snapshots.map(\.totalSpent)
        if amounts.count >= 3 {
            let recent = amounts.suffix(2).reduce(0, +) / 2
            let older = amounts.dropLast(2).reduce(0, +) / Double(amounts.count - 2)
            if recent > older * 1.1 { trend = .increasing } else if recent < older * 0.9 { trend = .decreasing }
        }

        let monthlyIncome = totalIncome / months
        let monthlySavings = (totalIncome - totalSpent) / months
        let savingsRate = monthlyIncome > 0 ? min(100, max(0, monthlySavings / monthlyIncome * 100)) : 0
        let runway = avgMonthly > 0 ? savingsBalance / avgMonthly : 0

        return FinancialSummary(
            totalSpent: totalSpent,
            avgDaily: totalSpent / Double(days),
            avgMonthly: avgMonthly,
            monthlyIncome: monthlyIncome,
            savings: savingsBalance,
            savingsRate: savingsRate,
            runwayMonths: runway,
            spendingTrend: trend,
            topCategories: top,
            monthlySnapshots: snapshots,
            seasonal: SeasonalSpend(winter: average(0), spring: average(1), summer: average(2), autumn: average(3)),
            dataRangeMonths: months
        )
    }
}
