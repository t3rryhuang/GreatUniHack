import Foundation

// Money Readiness: one 0-1000 Readiness Score built from five stats. Each stat
// mirrors a real-world credit factor, but this is a readiness score, not a
// credit score: it rewards consistency and improvement, never wealth or borrowing.

enum ReadinessStat: String, Codable, CaseIterable, Identifiable, Sendable {
    case reliability, balance, endurance, resilience, wisdom

    var id: String { rawValue }
    static let maxPoints = 200

    var title: String {
        switch self {
        case .reliability: "Reliability"
        case .balance: "Balance"
        case .endurance: "Endurance"
        case .resilience: "Resilience"
        case .wisdom: "Wisdom"
        }
    }

    /// The real-world credit factor this stat mirrors.
    var creditFactor: String {
        switch self {
        case .reliability: "Payment history"
        case .balance: "Credit utilisation"
        case .endurance: "Length of history"
        case .resilience: "Affordability"
        case .wisdom: "Restraint and money skills"
        }
    }

    var measures: String {
        switch self {
        case .reliability: "How often your bills and repayments are paid on time (within 3 days of the due date)."
        case .balance: "How many of the last 8 weeks your spending stayed under your weekly limit."
        case .endurance: "Your daily quest streak and how long you've been building a money history."
        case .resilience: "How many months your savings would cover your normal spending."
        case .wisdom: "Money Quest levels, the borrowing sandbox, what-ifs and daily quests."
        }
    }

    var howToRaise: String {
        switch self {
        case .reliability: "Pay every bill and family repayment on or before its due date."
        case .balance: "Keep each week's spending under your limit, even by a little."
        case .endurance: "Complete a daily quest every day to grow your streak."
        case .resilience: "Build a buffer of one month's spending, then keep going towards six."
        case .wisdom: "Play a Money Quest level (up to 3 a day count), try a what-if or finish the borrowing sandbox."
        }
    }

    var symbol: String {
        switch self {
        case .reliability: "checkmark.seal.fill"
        case .balance: "scalemass.fill"
        case .endurance: "hourglass"
        case .resilience: "umbrella.fill"
        case .wisdom: "lightbulb.fill"
        }
    }
}

enum ReadinessRank: String, Codable, CaseIterable, Identifiable, Sendable {
    case bronze, silver, gold, platinum, diamond

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    static func from(total: Int) -> ReadinessRank {
        switch total {
        case ..<300: .bronze
        case ..<500: .silver
        case ..<700: .gold
        case ..<850: .platinum
        default: .diamond
        }
    }

    /// Lowest score for this rank.
    var floor: Int {
        switch self {
        case .bronze: 0
        case .silver: 300
        case .gold: 500
        case .platinum: 700
        case .diamond: 850
        }
    }

    var next: ReadinessRank? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}

struct StatScore: Identifiable, Hashable, Sendable {
    var id: ReadinessStat { stat }
    let stat: ReadinessStat
    let points: Int
    /// A short plain-English fact behind the points, for example "11 of 12 on time".
    let detail: String
}

struct ReadinessScore: Hashable, Sendable {
    let stats: [StatScore]
    var total: Int { stats.reduce(0) { $0 + $1.points } }
    var rank: ReadinessRank { .from(total: total) }

    func points(for stat: ReadinessStat) -> Int { stats.first { $0.stat == stat }?.points ?? 0 }

    static let disclaimer = "This is a readiness score, not a credit score."
}

/// A payment that falls due on a date: a recurring bill, a shared bill or a loan instalment.
struct ScheduledPayment: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var amount: Double
    var due: Date
    var paid: Date?

    /// Paid no more than 3 days after the due date.
    var isOnTime: Bool {
        guard let paid else { return false }
        return paid <= due.addingTimeInterval(ReadinessRules.graceDays * 86_400)
    }
}

/// A bill detected from transactions: same merchant, similar amount, roughly monthly.
struct RecurringBill: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let amount: Double
    let dayOfMonth: Int
    let category: SpendingCategory
    let payments: [ScheduledPayment]
    let nextDue: Date
}

struct DailyScore: Codable, Hashable, Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let total: Int
}

/// Things that count towards Wisdom.
enum WisdomEvent: String, Codable, Sendable {
    case whatIf, lesson, sandbox, moneyQuestLevel
}

/// Everything the score needs, gathered by `AppModel`.
struct ReadinessInput: Sendable {
    var transactions: [Transaction]
    var summary: FinancialSummary
    var savingsBalance: Double
    /// Shared bills and loan instalments from Family (empty for adults).
    var familyPayments: [ScheduledPayment]
    var accountStart: Date
    var now: Date = .now
}

/// The result of an evaluation, shown on the Readiness screen.
struct ReadinessSnapshot: Hashable, Sendable {
    let score: ReadinessScore
    let history: [DailyScore]
    let bills: [RecurringBill]
    let payments: [ScheduledPayment]
    let weeklyTotals: [Double]
    let weeklyLimit: Double
    let streak: Int
    let longestStreak: Int
    let shieldsLeft: Int
    let quest: DailyQuest?
    let boss: WeeklyBoss?
    /// Set when the shield saved the streak in the last 7 days.
    let recentShield: ShieldEvent?

    /// Change over the last 30 days (0 if there is no history yet).
    var monthChange: Int {
        guard let first = history.first else { return 0 }
        return score.total - first.total
    }

    var onTimePayments: Int { payments.filter(\.isOnTime).count }

    /// Number of calendar months with at least one on-time payment and none missed.
    var onTimeMonths: Int {
        let calendar = Calendar.current
        var months: [DateComponents: Bool] = [:]
        for p in payments {
            let key = calendar.dateComponents([.year, .month], from: p.due)
            months[key] = (months[key] ?? true) && p.isOnTime
        }
        return months.values.filter { $0 }.count
    }
}

/// Pure scoring rules. No state and no I/O, so they are easy to read and test.
enum ReadinessRules {
    static let graceDays: Double = 3
    static let balanceWeeks = 8
    static let streakCap = 30
    static let ageCapMonths = 12.0
    static let runwayTargetMonths = 6.0
    static let bufferTarget = 100.0

    // MARK: Score

    static func score(_ input: ReadinessInput, progress: ReadinessProgress) -> (ReadinessScore, bills: [RecurringBill], payments: [ScheduledPayment], weekly: [Double], limit: Double) {
        let bills = recurringBills(in: input.transactions, now: input.now)
        let payments = (bills.flatMap(\.payments) + input.familyPayments).sorted { $0.due < $1.due }
        let rel = reliability(payments, now: input.now)
        let bal = balance(input.transactions, limit: progress.weeklyLimit, now: input.now)
        let end = endurance(streak: progress.streak, accountStart: input.accountStart, now: input.now)
        let res = resilience(runwayMonths: input.summary.runwayMonths, savings: input.savingsBalance)
        let wis = wisdom(progress)
        let months = max(0, Calendar.current.dateComponents([.month], from: input.accountStart, to: input.now).month ?? 0)
        let score = ReadinessScore(stats: [
            StatScore(stat: .reliability, points: rel.points, detail: rel.total == 0 ? "No bills found yet" : "\(rel.onTime) of \(rel.total) paid on time"),
            StatScore(stat: .balance, points: bal.points, detail: "\(bal.weeksUnder) of \(balanceWeeks) weeks under \(bal.limit.gbpWhole)"),
            StatScore(stat: .endurance, points: end, detail: "\(progress.streak)-day streak, \(months) months of history"),
            StatScore(stat: .resilience, points: res, detail: String(format: "%.1f months of spending saved", input.summary.runwayMonths)),
            StatScore(stat: .wisdom, points: wis, detail: "\(progress.moneyQuestLevels) Money Quest levels, \(progress.whatIfs) what-ifs, \(progress.questsCompleted) quests\(progress.sandboxDone ? ", sandbox done" : "")")
        ])
        return (score, bills, payments, bal.weekly, bal.limit)
    }

    // MARK: Reliability (payment history)

    /// Share of payments already due that were paid on time, scaled to 0-200.
    /// Unpaid payments still inside the 3-day grace period are left out.
    static func reliability(_ payments: [ScheduledPayment], now: Date) -> (points: Int, onTime: Int, total: Int) {
        let counted = payments.filter { p in
            guard p.due <= now else { return false }
            return p.paid != nil || now > p.due.addingTimeInterval(graceDays * 86_400)
        }
        guard !counted.isEmpty else { return (0, 0, 0) }
        let onTime = counted.filter(\.isOnTime).count
        return (Int((Double(onTime) / Double(counted.count) * 200).rounded()), onTime, counted.count)
    }

    /// Finds bills: the same merchant, an amount within ±15% of its usual amount,
    /// at least 3 times, roughly monthly (median gap 25-35 days).
    /// Transfers are left out (family payments are counted from Family instead).
    static func recurringBills(in transactions: [Transaction], now: Date, calendar: Calendar = .current) -> [RecurringBill] {
        let expenses = transactions.filter { $0.isExpense && $0.category != .transfer && $0.category != .income }
        let groups = Dictionary(grouping: expenses) { $0.description.lowercased().trimmingCharacters(in: .whitespaces) }
        var bills: [RecurringBill] = []
        for (_, group) in groups where group.count >= 3 {
            let usual = median(group.map(\.spend))
            let similar = group.filter { abs($0.spend - usual) <= usual * 0.15 }.sorted { $0.date < $1.date }
            guard similar.count >= 3 else { continue }
            let gaps = zip(similar, similar.dropFirst()).map { $1.date.timeIntervalSince($0.date) / 86_400 }
            guard (25.0...35.0).contains(median(gaps)) else { continue }
            let day = Int(median(similar.map { Double(calendar.component(.day, from: $0.date)) }))
            let payments = similar.map { t in
                ScheduledPayment(name: t.description, amount: t.spend, due: expectedDate(day: day, near: t.date, calendar: calendar), paid: t.date)
            }
            let last = similar.last?.date ?? now
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: last) ?? now
            bills.append(RecurringBill(
                name: similar.last?.description ?? "",
                amount: usual,
                dayOfMonth: day,
                category: similar.last?.category ?? .other,
                payments: payments,
                nextDue: expectedDate(day: day, near: nextMonth, calendar: calendar)
            ))
        }
        return bills.sorted { $0.nextDue < $1.nextDue }
    }

    /// The bill's usual day in the month nearest to `date` (clamped to the month's length).
    static func expectedDate(day: Int, near date: Date, calendar: Calendar = .current) -> Date {
        let candidates = [-1, 0, 1].compactMap { offset -> Date? in
            guard let month = calendar.date(byAdding: .month, value: offset, to: date),
                  let interval = calendar.dateInterval(of: .month, for: month),
                  let range = calendar.range(of: .day, in: .month, for: month) else { return nil }
            return calendar.date(byAdding: .day, value: min(day, range.count) - 1, to: interval.start)
        }
        let target = calendar.startOfDay(for: date)
        return candidates.min { abs($0.timeIntervalSince(target)) < abs($1.timeIntervalSince(target)) } ?? date
    }

    // MARK: Balance (utilisation)

    /// Everyday spending: everything except rent, bills, transfers and income.
    static func isEveryday(_ t: Transaction) -> Bool {
        t.isExpense && ![.rent, .utilities, .transfer, .income].contains(t.category)
    }

    /// Spending in each of the last 8 weeks (oldest first), as rolling 7-day windows ending today.
    static func weeklyTotals(_ transactions: [Transaction], now: Date, calendar: Calendar = .current) -> [Double] {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return (0..<balanceWeeks).reversed().map { index in
            let upper = end.addingTimeInterval(-Double(index) * 7 * 86_400)
            let lower = upper.addingTimeInterval(-7 * 86_400)
            return transactions.filter { isEveryday($0) && $0.date >= lower && $0.date < upper }.reduce(0) { $0 + $1.spend }
        }
    }

    /// Share of the last 8 weeks under the weekly limit (default: the 8-week average), 0-200.
    static func balance(_ transactions: [Transaction], limit: Double?, now: Date) -> (points: Int, weeksUnder: Int, limit: Double, weekly: [Double]) {
        let weekly = weeklyTotals(transactions, now: now)
        guard weekly.contains(where: { $0 > 0 }) else { return (0, 0, limit ?? 0, weekly) }
        let effective = limit ?? (weekly.reduce(0, +) / Double(weekly.count)).rounded()
        let under = weekly.filter { $0 <= effective }.count
        return (Int((Double(under) / Double(weekly.count) * 200).rounded()), under, effective, weekly)
    }

    // MARK: Endurance (length of history)

    /// Up to 100 for the streak (capped at 30 days) and 100 for account age (capped at 12 months).
    static func endurance(streak: Int, accountStart: Date, now: Date) -> Int {
        let streakPart = Double(min(max(streak, 0), streakCap)) / Double(streakCap) * 100
        let months = max(0, now.timeIntervalSince(accountStart) / (30.44 * 86_400))
        let agePart = min(months, ageCapMonths) / ageCapMonths * 100
        return Int((streakPart + agePart).rounded())
    }

    // MARK: Resilience (affordability)

    /// 0 months of runway is 0 points and 6+ months is 170, plus up to 30 for having started a buffer.
    static func resilience(runwayMonths: Double, savings: Double) -> Int {
        let runway = min(max(runwayMonths, 0), runwayTargetMonths) / runwayTargetMonths * 170
        let buffer = min(max(savings, 0), bufferTarget) / bufferTarget * 30
        return Int((runway + buffer).rounded())
    }

    // MARK: Wisdom (restraint and literacy)

    /// Money Quest levels 10 each (max 80; at most 3 a day count, see MoneyQuestRules),
    /// the borrowing sandbox 30, what-ifs and lessons 10 each (max 30), daily quests 2 each (max 60).
    static func wisdom(_ progress: ReadinessProgress) -> Int {
        min(progress.moneyQuestLevels * 10, 80)
            + (progress.sandboxDone ? 30 : 0)
            + min((progress.whatIfs + progress.lessons) * 10, 30)
            + min(progress.questsCompleted * 2, 60)
    }

    // MARK: Helpers

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}

/// What the user has done, saved on-device. New fields must be optional or
/// have decoding defaults so older saves still load.
struct ReadinessProgress: Codable, Hashable, Sendable {
    var streak = 0
    var longestStreak = 0
    var questsCompleted = 0
    var whatIfs = 0
    var lessons = 0
    var sandboxDone = false
    /// User-set weekly limit; nil means the 8-week average.
    var weeklyLimit: Double?
    var history: [DailyScore] = []
    /// Demo data asks for a 30-day history to be back-filled from the first real score.
    var seedHistory = false
    /// Daily quests, newest last (the last 60 days are kept).
    var quests: [DailyQuest] = []
    /// Months ("2026-11") in which the monthly shield has been used.
    var shieldMonths: [String] = []
    var lastShieldEvent: ShieldEvent?
    /// Graduation checklist items the teen ticks themselves.
    var votingChecked = false
    var reportPreviewed = false
    /// Money Quest levels that counted towards Wisdom.
    var moneyQuestLevels = 0

    init() {}

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        longestStreak = try c.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        questsCompleted = try c.decodeIfPresent(Int.self, forKey: .questsCompleted) ?? 0
        whatIfs = try c.decodeIfPresent(Int.self, forKey: .whatIfs) ?? 0
        lessons = try c.decodeIfPresent(Int.self, forKey: .lessons) ?? 0
        sandboxDone = try c.decodeIfPresent(Bool.self, forKey: .sandboxDone) ?? false
        weeklyLimit = try c.decodeIfPresent(Double.self, forKey: .weeklyLimit)
        history = try c.decodeIfPresent([DailyScore].self, forKey: .history) ?? []
        seedHistory = try c.decodeIfPresent(Bool.self, forKey: .seedHistory) ?? false
        quests = try c.decodeIfPresent([DailyQuest].self, forKey: .quests) ?? []
        shieldMonths = try c.decodeIfPresent([String].self, forKey: .shieldMonths) ?? []
        lastShieldEvent = try c.decodeIfPresent(ShieldEvent.self, forKey: .lastShieldEvent)
        votingChecked = try c.decodeIfPresent(Bool.self, forKey: .votingChecked) ?? false
        reportPreviewed = try c.decodeIfPresent(Bool.self, forKey: .reportPreviewed) ?? false
        moneyQuestLevels = try c.decodeIfPresent(Int.self, forKey: .moneyQuestLevels) ?? 0
    }
}

// MARK: Daily quest, streak, shield and weekly boss

struct DailyQuest: Codable, Hashable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable { case pending, completed, missed, shielded }

    var id: Date { date }
    /// Start of the quest's day.
    let date: Date
    let category: SpendingCategory
    /// Spend under this amount in the category (the predicted average spend).
    let limit: Double
    var status: Status = .pending

    var title: String { "Spend under \(limit.gbpWhole) on \(category.rawValue.lowercased()) today" }
}

struct ShieldEvent: Codable, Hashable, Sendable {
    let date: Date
    /// The streak the shield protected.
    let savedStreak: Int

    var message: String { "Your shield saved your \(savedStreak)-day streak" }
}

/// The next bill due in the coming week. "Defeated" when it's paid on time.
struct WeeklyBoss: Hashable, Sendable {
    enum Status: Sendable { case upcoming, defeated, missed }
    let name: String
    let amount: Double
    let due: Date
    let status: Status
}

extension ReadinessRules {
    static let questExcluded: Set<SpendingCategory> = [.rent, .utilities, .subscriptions, .transfer, .income]

    /// Today's quest from today's predictions: the most likely everyday spend,
    /// with the predicted average amount (rounded up to the pound) as the limit.
    static func makeQuest(from items: [PredictionItem], on date: Date, calendar: Calendar = .current) -> DailyQuest? {
        guard let item = items.filter({ !questExcluded.contains($0.category) && $0.amount > 0 })
            .max(by: { $0.probability < $1.probability }) else { return nil }
        return DailyQuest(date: calendar.startOfDay(for: date), category: item.category, limit: max(1, item.amount.rounded(.up)))
    }

    /// What was spent in the quest's category on the quest's day.
    static func spend(for quest: DailyQuest, in transactions: [Transaction], calendar: Calendar = .current) -> Double {
        transactions.filter { $0.isExpense && $0.category == quest.category && calendar.isDate($0.date, inSameDayAs: quest.date) }
            .reduce(0) { $0 + $1.spend }
    }

    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    static func shieldsLeft(_ progress: ReadinessProgress, now: Date) -> Int {
        progress.shieldMonths.contains(monthKey(now)) ? 0 : 1
    }

    /// Checks every finished day's quest against the transactions (in date order).
    /// A met quest extends the streak. A missed one uses the month's shield if it's
    /// still there, otherwise the streak resets.
    static func settleQuests(_ progress: ReadinessProgress, transactions: [Transaction], now: Date, calendar: Calendar = .current) -> ReadinessProgress {
        var p = progress
        let today = calendar.startOfDay(for: now)
        for index in p.quests.indices.sorted(by: { p.quests[$0].date < p.quests[$1].date }) {
            let quest = p.quests[index]
            guard quest.status == .pending, quest.date < today else { continue }
            if spend(for: quest, in: transactions, calendar: calendar) <= quest.limit {
                p.quests[index].status = .completed
                p.streak += 1
                p.questsCompleted += 1
            } else if !p.shieldMonths.contains(monthKey(quest.date, calendar: calendar)) {
                p.quests[index].status = .shielded
                p.shieldMonths.append(monthKey(quest.date, calendar: calendar))
                p.lastShieldEvent = ShieldEvent(date: quest.date, savedStreak: p.streak)
            } else {
                p.quests[index].status = .missed
                p.streak = 0
            }
            p.longestStreak = max(p.longestStreak, p.streak)
        }
        return p
    }

    /// The boss for this week: the soonest unpaid payment due in the next 7 days,
    /// otherwise one paid on time in the last 7 days (defeated), or one overdue (missed).
    static func weeklyBoss(bills: [RecurringBill], payments: [ScheduledPayment], now: Date, calendar: Calendar = .current) -> WeeklyBoss? {
        let today = calendar.startOfDay(for: now)
        let weekAhead = today.addingTimeInterval(8 * 86_400)
        let weekAgo = today.addingTimeInterval(-7 * 86_400)

        var upcoming = bills.filter { $0.nextDue >= today && $0.nextDue < weekAhead }
            .map { WeeklyBoss(name: $0.name, amount: $0.amount, due: $0.nextDue, status: .upcoming) }
        upcoming += payments.filter { $0.paid == nil && $0.due >= today && $0.due < weekAhead }
            .map { WeeklyBoss(name: $0.name, amount: $0.amount, due: $0.due, status: .upcoming) }
        if let next = upcoming.min(by: { $0.due < $1.due }) { return next }

        let overdue = payments.filter { $0.paid == nil && $0.due < today && $0.due >= weekAgo && now > $0.due.addingTimeInterval(graceDays * 86_400) }
        if let missed = overdue.max(by: { $0.due < $1.due }) {
            return WeeklyBoss(name: missed.name, amount: missed.amount, due: missed.due, status: .missed)
        }
        let beaten = payments.filter { $0.isOnTime && ($0.paid ?? .distantPast) >= weekAgo }
        if let won = beaten.max(by: { ($0.paid ?? $0.due) < ($1.paid ?? $1.due) }) {
            return WeeklyBoss(name: won.name, amount: won.amount, due: won.due, status: .defeated)
        }
        return nil
    }
}

// MARK: Borrowing sandbox

extension ReadinessRules {
    /// Monthly repayment for an example loan. APR 0 means interest-free (for example a family loan).
    static func monthlyPayment(amount: Double, months: Int, apr: Double) -> Double {
        let n = Double(max(1, months))
        guard apr > 0 else { return amount / n }
        let r = apr / 100 / 12
        return amount * r / (1 - pow(1 + r, -n))
    }

    /// Reliability points now, if all of `months` new payments are on time, and if one is missed.
    static func sandboxOutcome(payments: [ScheduledPayment], months: Int, now: Date) -> (now: Int, allOnTime: Int, oneMissed: Int) {
        let current = reliability(payments, now: now)
        let n = max(1, months)
        func points(_ onTime: Int, _ total: Int) -> Int { total == 0 ? 0 : Int((Double(onTime) / Double(total) * 200).rounded()) }
        return (current.points,
                points(current.onTime + n, current.total + n),
                points(current.onTime + n - 1, current.total + n))
    }
}

// MARK: Graduation (Teen mode)

enum GraduationItem: String, CaseIterable, Identifiable, Sendable {
    case vote, billStreak, buffer, sandbox, report

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vote: "Register to vote early"
        case .billStreak: "Keep your bill streak"
        case .buffer: "Build a buffer of one month's spending"
        case .sandbox: "Complete the borrowing sandbox"
        case .report: "Preview your Readiness Report"
        }
    }

    var detail: String {
        switch self {
        case .vote: "Lenders use the electoral register to confirm who you are. The age you can register and vote differs across England, Scotland, Wales and Northern Ireland, so check gov.uk/register-to-vote."
        case .billStreak: "Pay your bills and repayments on time for at least 3 months in a row."
        case .buffer: "Savings that would cover a normal month of your own spending."
        case .sandbox: "Try a practice loan in the Simulator and see what a missed payment does."
        case .report: "A one-page summary you can choose to share."
        }
    }

    /// Only voting is ticked by hand; the rest are checked from your data.
    var isManual: Bool { self == .vote }
}

extension ReadinessRules {
    static func isDone(_ item: GraduationItem, snapshot: ReadinessSnapshot?, progress: ReadinessProgress, summary: FinancialSummary, savings: Double) -> Bool {
        switch item {
        case .vote: progress.votingChecked
        case .billStreak: recentOnTimeMonths(snapshot?.payments ?? [], now: .now) >= 3
        case .buffer: summary.avgMonthly > 0 && savings >= summary.avgMonthly
        case .sandbox: progress.sandboxDone
        case .report: progress.reportPreviewed
        }
    }

    /// Consecutive months, counting back from the latest month with a payment due,
    /// in which every payment was on time.
    static func recentOnTimeMonths(_ payments: [ScheduledPayment], now: Date, calendar: Calendar = .current) -> Int {
        let due = payments.filter { $0.due <= now && ($0.paid != nil || now > $0.due.addingTimeInterval(graceDays * 86_400)) }
        let byMonth = Dictionary(grouping: due) { monthKey($0.due, calendar: calendar) }
        var streak = 0
        for key in byMonth.keys.sorted(by: >) {
            guard byMonth[key]?.allSatisfy(\.isOnTime) == true else { break }
            streak += 1
        }
        return streak
    }
}

// MARK: Hardship protection (F8)

extension ReadinessRules {
    /// Income in the last complete calendar month compared with the month before.
    /// Returns that ratio when income fell by more than 30%, otherwise 1.
    static func hardshipScale(_ transactions: [Transaction], now: Date = .now, calendar: Calendar = .current) -> Double {
        guard let thisMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth),
              let monthBefore = calendar.date(byAdding: .month, value: -2, to: thisMonth) else { return 1 }
        func income(_ from: Date, _ to: Date) -> Double {
            transactions.filter { $0.category == .income && $0.amount > 0 && $0.date >= from && $0.date < to }.reduce(0) { $0 + $1.amount }
        }
        let recent = income(lastMonth, thisMonth)
        let before = income(monthBefore, lastMonth)
        guard before > 0, recent < before * 0.7 else { return 1 }
        return max(0.3, recent / before)
    }
}
