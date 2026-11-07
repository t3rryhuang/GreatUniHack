import Foundation

/// Mock predictions and insights computed on-device from the user's transactions.
/// The real backend (multi-model consensus) will replace this behind `InsightsServicing`.
class MockInsightsService: InsightsServicing {
    private let calendar = Calendar.current
    private let models = ["Claude", "Gemini", "GPT"]

    init() {}

    func weather() async throws -> Weather {
        await simulateLatency(250)
        let day = calendar.ordinality(of: .day, in: .year, for: .now) ?? 1
        let conditions: [WeatherCondition] = [.cloudy, .drizzle, .rain, .sunny, .drizzle, .wind, .cloudy]
        let condition = conditions[day % conditions.count]
        let month = calendar.component(.month, from: .now)
        let base = [6, 7, 9, 12, 15, 18, 21, 21, 18, 14, 10, 7][month - 1]
        let impact: String = switch condition {
        case .rain, .drizzle: "Rainy days usually mean more Uber trips and food delivery."
        case .sunny: "Sunny days usually mean more pub and park spending."
        case .cold: "Cold days push up coffee and heating costs."
        case .wind, .cloudy: "A normal day for your spending."
        }
        return Weather(city: "Manchester", temperatureC: base + day % 4 - 1, condition: condition, spendingImpact: impact)
    }

    func weekAhead(from transactions: [Transaction]) async throws -> [DayPrediction] {
        await simulateLatency(600)
        let today = calendar.startOfDay(for: .now)
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return DayPrediction(date: date, items: predictions(for: date, from: transactions))
        }
    }

    func briefing(from transactions: [Transaction], name: String) async throws -> MorningBriefing {
        let weather = try await weather()
        let today = calendar.startOfDay(for: .now)
        let items = predictions(for: today, from: transactions)
        let top = items.first
        let expected = items.reduce(0) { $0 + $1.amount * $1.probability }
        let hour = calendar.component(.hour, from: .now)
        let greeting = switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
        let nudge: String
        if let top, top.category == .coffee {
            nudge = "Making coffee at home today would save about \(top.amount.gbp)."
        } else if let top {
            nudge = "You're likely to spend on \(top.category.rawValue.lowercased()) today. Set yourself a limit of \((top.amount * 0.8).gbp)."
        } else {
            nudge = "A quiet day ahead. A great chance to move a little into savings."
        }
        let script = """
        \(greeting), \(name). It's \(weather.temperatureC) degrees and \(weather.condition.label.lowercased()) in Manchester. \
        \(weather.spendingImpact) Today I expect you to spend around \(expected.gbp)\(top.map { ", most likely on \($0.title.lowercased())" } ?? ""). \
        \(nudge)
        """
        return MorningBriefing(greeting: "\(greeting), \(name)", weather: weather, topPrediction: top, expectedSpend: expected, nudge: nudge, script: script)
    }

    func alerts(from transactions: [Transaction]) async throws -> [SpendingAlert] {
        await simulateLatency(300)
        let expenses = transactions.filter(\.isExpense)
        guard !expenses.isEmpty else { return [] }
        var averages: [SpendingCategory: Double] = [:]
        var counts: [SpendingCategory: Int] = [:]
        for t in expenses {
            averages[t.category, default: 0] += t.spend
            counts[t.category, default: 0] += 1
        }
        for (key, total) in averages { averages[key] = total / Double(counts[key] ?? 1) }

        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: .now) ?? .now
        var result: [SpendingAlert] = []
        let spikes = expenses
            .filter { $0.date >= twoWeeksAgo && $0.category != .rent && $0.category != .utilities && $0.category != .transfer }
            .filter { $0.spend > (averages[$0.category] ?? 0) * 2.5 && $0.spend > 25 }
            .sorted { $0.spend > $1.spend }
            .prefix(2)
        for t in spikes {
            let multiple = t.spend / max(1, averages[t.category] ?? 1)
            result.append(SpendingAlert(
                kind: .spike,
                title: "Unusual \(t.category.rawValue.lowercased()) spend",
                message: "\(t.amount.magnitude.gbp) at \(t.description) on \(t.date.formatted(.dateTime.weekday(.wide))) is \(String(format: "%.1f", multiple))× your usual.",
                merchant: t.description,
                amount: t.spend
            ))
        }

        // Week-over-week trend for the top discretionary category.
        let thisWeek = weekTotals(expenses, weeksAgo: 0)
        let lastWeek = weekTotals(expenses, weeksAgo: 1)
        if let (category, value) = thisWeek.filter({ SpendingCategory.vices.contains($0.key) }).max(by: { $0.value < $1.value }),
           let previous = lastWeek[category], previous > 0, value > previous * 1.3 {
            result.append(SpendingAlert(
                kind: .trend,
                title: "\(category.rawValue) is trending up",
                message: "You've spent \(value.gbp) on \(category.rawValue.lowercased()) this week, up \(Int((value / previous - 1) * 100))% on last week.",
                merchant: nil,
                amount: value
            ))
        }
        return result
    }

    func weeklyRecap(from transactions: [Transaction]) async throws -> WeeklyRecap {
        await simulateLatency(400)
        let expenses = transactions.filter { $0.isExpense && $0.category != .rent && $0.category != .transfer }
        let lastWeek = weekTotals(expenses, weeksAgo: 1)
        let actual = lastWeek.values.reduce(0, +)
        // Prediction = average of the 4 weeks before that.
        let history = (2...5).map { weekTotals(expenses, weeksAgo: $0).values.reduce(0, +) }
        let predicted = history.reduce(0, +) / Double(max(1, history.count))
        let accuracy = actual > 0 ? max(55, min(98, 100 - abs(predicted - actual) / actual * 100)) : 0
        let top = lastWeek.max { $0.value < $1.value }?.key
        var highlights: [String] = []
        if let top, let value = lastWeek[top] {
            highlights.append("\(top.rawValue) was your biggest category at \(value.gbp).")
        }
        let coffeeCount = transactions.filter { $0.category == .coffee && isInWeek($0.date, weeksAgo: 1) }.count
        if coffeeCount > 0 { highlights.append("You bought \(coffeeCount) coffees.") }
        highlights.append(actual <= predicted
            ? "You spent \((predicted - actual).gbp) less than predicted. Nice work."
            : "You spent \((actual - predicted).gbp) more than predicted.")
        return WeeklyRecap(accuracy: accuracy, predictedTotal: predicted, actualTotal: actual, highlights: highlights, topCategory: top)
    }

    func runway(summary: FinancialSummary) async throws -> RunwayResult {
        await simulateLatency(500)
        let months = summary.avgMonthly > 0 ? summary.savings / summary.avgMonthly : 0
        let essentials = summary.topCategories
            .filter { [.rent, .utilities, .groceries, .transport].contains($0.category) }
            .reduce(0) { $0 + $1.amount } / max(1, summary.dataRangeMonths)
        let lean = essentials > 0 ? summary.savings / essentials : months
        let analysis = """
        With \(summary.savings.gbp) saved and spending of \(summary.avgMonthly.gbp) a month, \
        you could last \(String(format: "%.1f", months)) months without income. \
        If you cut back to essentials only (\(essentials.gbp) a month), that stretches to \(String(format: "%.1f", lean)) months.
        """
        return RunwayResult(months: months, analysis: analysis)
    }

    func budgetTips(summary: FinancialSummary) async throws -> [String] {
        await simulateLatency(700)
        var tips: [String] = []
        let months = max(1, summary.dataRangeMonths)
        for total in summary.topCategories.prefix(6) {
            let monthly = total.amount / months
            switch total.category {
            case .dining: tips.append("Dining out costs you \(monthly.gbp) a month. Cooking two more dinners a week could save about \((monthly * 0.3).gbp).")
            case .coffee: tips.append("Coffee shops cost you \(monthly.gbp) a month. A reusable cup gets you money off at most coffee chains.")
            case .transport: tips.append("Transport is \(monthly.gbp) a month. Bee Network buses and Metrolink cap daily fares, so tap the same card every time.")
            case .shopping: tips.append("Shopping is \(monthly.gbp) a month. Try a 48-hour wait before any purchase over £30.")
            case .subscriptions: tips.append("You pay \(monthly.gbp) a month in subscriptions. Review any you haven't used in 30 days.")
            case .drinks: tips.append("Nights out cost \(monthly.gbp) a month. Setting a cash limit before you go helps.")
            default: continue
            }
        }
        if summary.savingsRate < 15 {
            tips.append("You're saving \(Int(summary.savingsRate))% of your income. Setting up a standing order on payday makes saving automatic.")
        }
        return Array(tips.prefix(4))
    }

    func whatIf(_ question: String, summary: FinancialSummary, transactions: [Transaction]) async throws -> WhatIfResult {
        await simulateLatency(1_100)
        return WhatIfEngine.answer(question, summary: summary, transactions: transactions)
    }

    // MARK: Helpers

    private func predictions(for date: Date, from transactions: [Transaction]) -> [PredictionItem] {
        let weekday = calendar.component(.weekday, from: date)
        let predictable = SpendingCategory.vices + [.transport, .groceries]
        let expenses = transactions.filter { $0.isExpense && predictable.contains($0.category) }
        guard let earliest = expenses.map(\.date).min() else { return [] }
        let weeks = max(1, Double(calendar.dateComponents([.day], from: earliest, to: .now).day ?? 7) / 7)

        var dayCounts: [SpendingCategory: Set<Date>] = [:]
        var totals: [SpendingCategory: (sum: Double, count: Int)] = [:]
        for t in expenses where calendar.component(.weekday, from: t.date) == weekday {
            dayCounts[t.category, default: []].insert(calendar.startOfDay(for: t.date))
            let entry = totals[t.category, default: (0, 0)]
            totals[t.category] = (entry.sum + t.spend, entry.count + 1)
        }

        let seed = calendar.component(.day, from: date)
        return dayCounts.compactMap { category, days -> PredictionItem? in
            let probability = min(0.97, Double(days.count) / weeks)
            guard probability >= 0.15, let total = totals[category] else { return nil }
            let average = total.sum / Double(total.count)
            let agreeCount = probability > 0.6 ? 3 : (probability > 0.35 ? 2 : 1)
            let rotated = Array((models + models).dropFirst(seed % 3).prefix(3))
            return PredictionItem(
                category: category,
                title: title(for: category, weekday: weekday),
                probability: probability,
                amount: (average * 100).rounded() / 100,
                agreedBy: Array(rotated.prefix(agreeCount))
            )
        }
        .sorted { $0.probability > $1.probability }
        .prefix(4)
        .map { $0 }
    }

    private func title(for category: SpendingCategory, weekday: Int) -> String {
        let weekend = weekday == 1 || weekday == 7
        return switch category {
        case .coffee: weekend ? "Weekend coffee" : "Morning coffee"
        case .dining: weekend ? "Brunch or dinner out" : "Lunch out"
        case .drinks: weekend ? "Night out" : "After-work drinks"
        case .transport: weekend ? "Getting around" : "Commute"
        case .groceries: "Food shop"
        case .shopping: "Shopping"
        case .entertainment: "Going out"
        default: category.rawValue
        }
    }

    private func isInWeek(_ date: Date, weeksAgo: Int) -> Bool {
        guard let reference = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: .now),
              let interval = calendar.dateInterval(of: .weekOfYear, for: reference) else { return false }
        return interval.contains(date)
    }

    private func weekTotals(_ expenses: [Transaction], weeksAgo: Int) -> [SpendingCategory: Double] {
        var result: [SpendingCategory: Double] = [:]
        for t in expenses where isInWeek(t.date, weeksAgo: weeksAgo) {
            result[t.category, default: 0] += t.spend
        }
        return result
    }
}

/// Rule-based answers for the Simulator. Ported from the original
/// `generateMockResponse`, with Manchester figures and pounds.
enum WhatIfEngine {
    static func answer(_ question: String, summary: FinancialSummary, transactions: [Transaction]) -> WhatIfResult {
        let q = question.lowercased()
        let months = max(1, summary.dataRangeMonths)
        let monthly = max(1, summary.avgMonthly)
        let savings = summary.savings
        let runway = savings / monthly
        func monthlySpend(_ category: SpendingCategory) -> Double {
            transactions.filter { $0.category == category && $0.isExpense }.reduce(0) { $0 + $1.spend } / months
        }
        func make(_ outcome: String, _ amount: Double, _ period: String, _ positive: Bool,
                  _ before: (String, Double), _ after: (String, Double), _ confidence: Int, _ details: String) -> WhatIfResult {
            WhatIfResult(question: question, outcome: outcome, amount: amount, period: period, isPositive: positive,
                         beforeLabel: before.0, beforeValue: before.1, afterLabel: after.0, afterValue: after.1,
                         confidence: confidence, details: details)
        }

        if q.contains("quit") || q.contains("lose my job") || q.contains("no income") {
            return make(
                "With \(savings.gbp) saved and \(monthly.gbp) of monthly spending, you could last \(String(format: "%.1f", runway)) months without income.",
                0, "", false, ("Monthly income", summary.monthlyIncome), ("Monthly income", 0), 87,
                "Your biggest costs are \(summary.topCategories.prefix(2).map { $0.category.rawValue.lowercased() }.joined(separator: " and ")). Freelance work at half your current salary would make your savings last indefinitely."
            )
        }
        if q.contains("eating out") || q.contains("restaurant") || q.contains("takeaway") || q.contains("food") {
            let dining = monthlySpend(.dining)
            let saved = dining / 2
            return make(
                "Cutting eating out by 50% would save you \(saved.gbp) a month, based on your average of \(dining.gbp).",
                saved, "month", true, ("Current dining", dining), ("After cutting", dining - saved), 92,
                "That's \((saved * 12).gbp) a year, enough to add \(String(format: "%.1f", saved * 12 / monthly)) months to your runway."
            )
        }
        if q.contains("subscription") || q.contains("netflix") || q.contains("spotify") {
            let subs = monthlySpend(.subscriptions)
            return make(
                "Cancelling all subscriptions would save you \(subs.gbp) a month.",
                subs, "month", true, ("Current subs", subs), ("After cancelling", 0), 98,
                "Keep the ones you use every week and cancel the rest. Most people save about half."
            )
        }
        if q.contains("move") || q.contains("cheaper") || q.contains("rent") || q.contains("relocate") {
            let rent = monthlySpend(.rent)
            let newRent = rent * 0.78
            return make(
                "Moving to a cheaper area could save you \((rent - newRent).gbp) a month: \(newRent.gbp) instead of \(rent.gbp).",
                rent - newRent, "month", true, ("Current rent", rent), ("New rent", newRent), 73,
                "Areas further out on the Metrolink, like Stretford, Eccles or Levenshulme, average 15–25% lower rent than the city centre. Allow £40–£80 a month for a longer commute and £600–£1,000 for moving costs."
            )
        }
        if q.contains("coffee") || q.contains("latte") || q.contains("pret") {
            let coffee = monthlySpend(.coffee)
            return make(
                "Making coffee at home would save you about \((coffee - 15).gbp) a month.",
                max(0, coffee - 15), "month", true, ("Coffee shops", coffee), ("Home coffee", 15), 94,
                "Good beans cost about £15 a month. That's \((max(0, coffee - 15) * 12).gbp) a year."
            )
        }
        if q.contains("cycl") || q.contains("bike") || q.contains("commute") || q.contains("walk") {
            let transport = monthlySpend(.transport)
            return make(
                "Cycling instead of taking the Metrolink or bus would save you about \((transport * 0.7).gbp) a month.",
                transport * 0.7, "month", true, ("Transport now", transport), ("Cycling", transport * 0.3), 88,
                "A commuter bike costs £300–£500 and pays for itself in a few months. The Cycle to Work scheme can save you a further 25–39%."
            )
        }
        if q.contains("save") || q.contains("saving") {
            let amount = 200.0
            let yearly = amount * 12 * 1.0125
            return make(
                "Saving £200 a month would grow to \(yearly.gbp) in a year at 1.25% interest.",
                yearly, "year", true, ("Current savings", savings), ("After 1 year", savings + yearly), 95,
                "That adds \(String(format: "%.1f", yearly / monthly)) months to your runway. A standing order on payday makes it automatic."
            )
        }
        let estimate = monthly * 0.06
        return make(
            "Based on your spending, this change could save you about \(estimate.gbp) a month if you stick with it.",
            estimate, "month", true, ("Current spend", monthly), ("After change", monthly - estimate), 70,
            "Small, steady changes add up. Try it for one month and check your weekly recap."
        )
    }
}
