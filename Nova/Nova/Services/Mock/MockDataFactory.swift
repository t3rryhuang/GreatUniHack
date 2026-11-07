import Foundation

/// Generates a realistic, repeatable year of Manchester transactions for demo mode.
/// Replaces the original demo datasets.
enum MockDataFactory {
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }

    static let merchants: [SpendingCategory: [String]] = [
        .coffee: ["Pret A Manger", "Costa Coffee", "Grindsmith", "Caffè Nero", "Federal Cafe"],
        .groceries: ["Tesco Express", "Sainsbury's Local", "Waitrose", "Lidl", "M&S Food", "Ocado"],
        .dining: ["Mowgli", "Nando's", "Wagamama", "Rudy's Pizza", "Deliveroo", "Bundobust"],
        .drinks: ["The Briton's Protection", "BrewDog Outpost", "Wetherspoon", "Albert's Schloss"],
        .transport: ["Metrolink", "Bee Network Bus", "Uber", "Northern Rail", "Bolt"],
        .shopping: ["Amazon", "ASOS", "John Lewis", "Uniqlo", "Primark", "Zara"],
        .entertainment: ["Odeon Cinema", "Ticketmaster", "Eventbrite", "Steam", "Vue Cinema"],
        .healthcare: ["Boots", "Superdrug", "Dentist Practice"],
        .education: ["Waterstones", "Udemy", "Coursera"]
    ]

    /// Fixed monthly bills.
    static let bills: [(String, Double, SpendingCategory, Int)] = [
        ("Rent - Landlord Payment", 1_050, .rent, 1),
        ("Octopus Energy", 92, .utilities, 3),
        ("United Utilities", 36, .utilities, 5),
        ("Council Tax - Manchester City Council", 118, .utilities, 6),
        ("EE Mobile", 24, .utilities, 10),
        ("Netflix", 10.99, .subscriptions, 12),
        ("Spotify", 11.99, .subscriptions, 14),
        ("PureGym", 24.99, .subscriptions, 2),
        ("iCloud+ apple.com", 2.99, .subscriptions, 18)
    ]

    /// Typical per-visit cost and visits per week for discretionary categories.
    static let habits: [(SpendingCategory, ClosedRange<Double>, Double)] = [
        (.coffee, 3.2...5.8, 4.5),
        (.groceries, 9...48, 2.6),
        (.dining, 11...38, 2.0),
        (.drinks, 6...32, 1.4),
        (.transport, 2.8...19, 6.0),
        (.shopping, 12...85, 0.9),
        (.entertainment, 9...45, 0.5),
        (.healthcare, 4...30, 0.2),
        (.education, 8...25, 0.12)
    ]

    static func demoTransactions(months: Int = 12, now: Date = .now, seed: UInt64 = 2026) -> [Transaction] {
        var rng = SeededGenerator(seed: seed)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .month, value: -months, to: today) else { return [] }

        var result: [Transaction] = []
        var day = start
        while day <= today {
            let dayOfMonth = calendar.component(.day, from: day)
            let month = calendar.component(.month, from: day)
            let weekday = calendar.component(.weekday, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            // People spend a little more in December and summer.
            let seasonal: Double = switch month {
            case 12: 1.35
            case 7, 8: 1.15
            case 1, 2: 0.9
            default: 1
            }

            if dayOfMonth == 25 {
                result.append(Transaction(date: at(day, hour: 9, calendar), description: "Salary - Payroll", amount: 2_850, category: .income))
            }
            for (name, amount, category, billDay) in bills where billDay == dayOfMonth {
                result.append(Transaction(date: at(day, hour: 7, calendar), description: name, amount: -amount, category: category))
            }
            if dayOfMonth == 26 {
                result.append(Transaction(date: at(day, hour: 8, calendar), description: "Transfer to Flexible Saver", amount: -250, category: .transfer))
            }

            for (category, range, perWeek) in habits {
                var chance = perWeek / 7 * seasonal
                if isWeekend && (category == .drinks || category == .dining || category == .entertainment) { chance *= 1.8 }
                if isWeekend && category == .coffee { chance *= 0.6 }
                var visits = 0
                while chance > 0 {
                    if Double.random(in: 0...1, using: &rng) < min(chance, 1) { visits += 1 }
                    chance -= 1
                }
                for _ in 0..<visits {
                    let names = merchants[category] ?? ["Card payment"]
                    let name = names[Int.random(in: 0..<names.count, using: &rng)]
                    let amount = (Double.random(in: range, using: &rng) * 100).rounded() / 100
                    let hour = hourFor(category, rng: &rng)
                    result.append(Transaction(date: at(day, hour: hour, calendar), description: name, amount: -amount, category: category))
                }
            }

            // A couple of one-off spikes so the alerts have something to find.
            if calendar.isDate(day, inSameDayAs: calendar.date(byAdding: .day, value: -3, to: today) ?? today) {
                result.append(Transaction(date: at(day, hour: 20, calendar), description: "ASOS", amount: -142.50, category: .shopping))
            }
            if calendar.isDate(day, inSameDayAs: calendar.date(byAdding: .day, value: -9, to: today) ?? today) {
                result.append(Transaction(date: at(day, hour: 23, calendar), description: "Uber", amount: -46.20, category: .transport))
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result.sorted { $0.date > $1.date }
    }

    private static func at(_ day: Date, hour: Int, _ calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: (hour * 7) % 60, second: 0, of: day) ?? day
    }

    private static func hourFor(_ category: SpendingCategory, rng: inout SeededGenerator) -> Int {
        switch category {
        case .coffee: Int.random(in: 7...10, using: &rng)
        case .dining: [12, 13, 19, 20].randomElement(using: &rng) ?? 13
        case .drinks: Int.random(in: 18...22, using: &rng)
        case .transport: [8, 9, 18, 23].randomElement(using: &rng) ?? 8
        default: Int.random(in: 10...20, using: &rng)
        }
    }

    // MARK: Teen demo (Jamie, 17, Manchester)

    static let teenName = "Jamie Patel"
    static let teenEmail = "jamie.patel@example.com"

    /// 17 years and 7 months old, so the 18th birthday is about 5 months away.
    static func teenDateOfBirth(now: Date = .now) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let birthday = calendar.date(byAdding: DateComponents(year: -17, month: -7), to: calendar.startOfDay(for: now)) ?? now
        return birthday
    }

    /// One family payment that is due on a date and may have been paid.
    struct DemoPayment {
        let due: Date
        let paid: Date?
        let amount: Double
    }

    /// The £10 phone bill share Jamie pays Mum on the 12th. One payment was 5 days late.
    static func teenPhoneShare(now: Date = .now) -> [DemoPayment] {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        var result: [DemoPayment] = []
        for monthsAgo in (0...5).reversed() {
            guard let month = calendar.date(byAdding: .month, value: -monthsAgo, to: today),
                  let due = calendar.date(bySetting: .day, value: 12, of: calendar.dateInterval(of: .month, for: month)?.start ?? month),
                  due <= today else { continue }
            let late = monthsAgo == 3
            let paid = calendar.date(byAdding: .day, value: late ? 5 : 0, to: due)
            result.append(DemoPayment(due: due, paid: paid, amount: 10))
        }
        return result
    }

    /// £120 from Mum for driving lessons, repaid at £30 a month. Two of four paid so far.
    static func teenLoanSchedule(now: Date = .now) -> (approved: Date, payments: [DemoPayment]) {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        let approved = calendar.date(byAdding: .day, value: -75, to: today) ?? today
        let payments = (1...4).compactMap { index -> DemoPayment? in
            guard let due = calendar.date(byAdding: .month, value: index, to: approved) else { return nil }
            let paid: Date? = due <= today ? calendar.date(byAdding: .day, value: -1, to: due) : nil
            return DemoPayment(due: due, paid: paid, amount: 30)
        }
        return (approved, payments)
    }

    /// Jamie's family set-up, matching the teen transactions.
    static func teenFamily(now: Date = .now) -> FamilyState {
        let calendar = Calendar(identifier: .gregorian)
        let loan = teenLoanSchedule(now: now)
        let phone = teenPhoneShare(now: now)
        return FamilyState(
            loans: [FamilyLoan(
                purpose: "Driving lessons",
                amount: 120,
                instalments: 4,
                lenderName: "Mum",
                relationship: "Parent",
                requestedAt: calendar.date(byAdding: .day, value: -1, to: loan.approved) ?? loan.approved,
                approvedAt: loan.approved,
                status: .approved,
                payments: loan.payments.map { FamilyPayment(due: $0.due, amount: $0.amount, paid: $0.paid) }
            )],
            bills: [SharedBill(
                name: "Phone bill share",
                amount: 10,
                dayOfMonth: 12,
                partnerName: "Mum",
                relationship: "Parent",
                startDate: phone.first?.due ?? now,
                payments: phone.map { FamilyPayment(due: $0.due, amount: $0.amount, paid: $0.paid) }
            )]
        )
    }

    static let teenHabits: [(SpendingCategory, [String], ClosedRange<Double>, Double)] = [
        (.dining, ["Greggs", "Subway", "Nando's", "McDonald's", "Chicken Cottage"], 3...11, 3.2),
        (.transport, ["Bee Network Bus", "Metrolink"], 1...2.8, 4.5),
        (.coffee, ["Costa Coffee", "Starbucks"], 2.6...4.4, 1.0),
        (.entertainment, ["Vue Cinema", "Steam", "Odeon Cinema", "Hollywood Bowl"], 5...16, 0.6),
        (.shopping, ["Primark", "JD Sports", "Amazon", "H&M"], 6...35, 0.5),
        (.groceries, ["Tesco Express", "Co-op"], 2...9, 1.0)
    ]

    /// Six months for a 17-year-old with a part-time job: about £400 a month in wages,
    /// small everyday spending, the phone bill share and repayments to Mum.
    static func teenTransactions(months: Int = 6, now: Date = .now, seed: UInt64 = 1717) -> [Transaction] {
        var rng = SeededGenerator(seed: seed)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .month, value: -months, to: today) else { return [] }

        var result: [Transaction] = []
        var day = start
        var weekIndex = 0
        while day <= today {
            let weekday = calendar.component(.weekday, from: day)
            let dayOfMonth = calendar.component(.day, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            // Paid every other Friday for weekend and after-school shifts.
            if weekday == 6 {
                weekIndex += 1
                if weekIndex % 2 == 0 {
                    let wage = (Double.random(in: 176...214, using: &rng) * 100).rounded() / 100
                    result.append(Transaction(date: at(day, hour: 9, calendar), description: "Wages - Cafe job payroll", amount: wage, category: .income))
                }
            }
            if dayOfMonth == 1 {
                result.append(Transaction(date: at(day, hour: 8, calendar), description: "Transfer to Flexible Saver", amount: -40, category: .transfer))
            }
            for (category, names, range, perWeek) in teenHabits {
                var chance = perWeek / 7
                if isWeekend && (category == .entertainment || category == .shopping) { chance *= 1.8 }
                if !isWeekend && category == .transport { chance *= 1.2 }
                if Double.random(in: 0...1, using: &rng) < min(chance, 1) {
                    let name = names[Int.random(in: 0..<names.count, using: &rng)]
                    let amount = (Double.random(in: range, using: &rng) * 100).rounded() / 100
                    result.append(Transaction(date: at(day, hour: hourFor(category, rng: &rng), calendar), description: name, amount: -amount, category: category))
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        // Family payments, matching the Family screen.
        for payment in teenPhoneShare(now: now) {
            if let paid = payment.paid, paid >= start {
                result.append(Transaction(date: at(paid, hour: 18, calendar), description: "Transfer to Mum - phone bill share", amount: -payment.amount, category: .transfer))
            }
        }
        let loan = teenLoanSchedule(now: now)
        result.append(Transaction(date: at(loan.approved, hour: 19, calendar), description: "Transfer from Mum - driving lessons loan", amount: 120, category: .transfer))
        result.append(Transaction(date: at(loan.approved, hour: 20, calendar), description: "Driving lessons", amount: -120, category: .education))
        for payment in loan.payments {
            if let paid = payment.paid {
                result.append(Transaction(date: at(paid, hour: 18, calendar), description: "Transfer to Mum - loan repayment", amount: -payment.amount, category: .transfer))
            }
        }
        return result.sorted { $0.date > $1.date }
    }

    // MARK: Arenas

    static let friendNames = ["Priya Shah", "Tom Okafor", "Ellie Clarke", "Sam Hughes", "Aisha Rahman", "Jack Murphy"]

    /// Teen arenas never use money: the winner earns points and badges.
    static func teenArenas(currentUser: UserProfile, now: Date = .now) -> [Arena] {
        let calendar = Calendar.current
        func days(_ value: Int) -> Date { calendar.date(byAdding: .day, value: value, to: now) ?? now }
        return [
            Arena(
                name: "Sixth Form Spend-Off",
                mode: .mostImproved,
                targetAmount: 0,
                stakeAmount: 0,
                startDate: days(-10),
                endDate: days(11),
                joinCode: "604218",
                status: .active,
                members: [
                    ArenaMember(name: currentUser.name, isCurrentUser: true, currentSpend: 58, lastSyncedAt: now, baselineSpend: 84),
                    ArenaMember(name: "Maya Ahmed", currentSpend: 61, lastSyncedAt: now, baselineSpend: 80),
                    ArenaMember(name: "Leo Byrne", currentSpend: 70, lastSyncedAt: now, baselineSpend: 76),
                    ArenaMember(name: "Zara Khan", currentSpend: 49, lastSyncedAt: now, baselineSpend: 72)
                ]
            ),
            Arena(
                name: "Festival Fund",
                mode: .savingsSprint,
                targetAmount: 150,
                stakeAmount: 0,
                startDate: days(-20),
                endDate: days(25),
                joinCode: "830571",
                status: .active,
                members: [
                    ArenaMember(name: currentUser.name, isCurrentUser: true, currentSavings: 80, lastSyncedAt: now),
                    ArenaMember(name: "Maya Ahmed", currentSavings: 95, lastSyncedAt: now)
                ]
            ),
            Arena(
                name: "October Budget Battle",
                mode: .budgetGuardian,
                targetAmount: 120,
                stakeAmount: 0,
                startDate: days(-38),
                endDate: days(-8),
                joinCode: "275139",
                status: .completed,
                members: [
                    ArenaMember(id: teenWinnerID, name: currentUser.name, isCurrentUser: true, currentSpend: 104, lastSyncedAt: days(-8)),
                    ArenaMember(name: "Leo Byrne", currentSpend: 117, lastSyncedAt: days(-8)),
                    ArenaMember(name: "Zara Khan", currentSpend: 131, exceededAt: days(-12), lastSyncedAt: days(-8))
                ],
                winnerID: teenWinnerID
            )
        ]
    }

    private static let teenWinnerID = UUID(uuidString: "0B1D5C1E-7EE0-4A11-9C55-2A7F3E6B9D01") ?? UUID()

    static func demoArenas(currentUser: UserProfile, stage: LifeStage = .adult, now: Date = .now) -> [Arena] {
        if stage == .teen { return teenArenas(currentUser: currentUser, now: now) }
        let calendar = Calendar.current
        func days(_ value: Int) -> Date { calendar.date(byAdding: .day, value: value, to: now) ?? now }
        let me = ArenaMember(name: currentUser.name, isCurrentUser: true, currentSpend: 212, currentSavings: 180, lastSyncedAt: now)

        return [
            Arena(
                name: "Flatmates' February",
                mode: .budgetGuardian,
                targetAmount: 400,
                stakeAmount: 10,
                startDate: days(-12),
                endDate: days(9),
                joinCode: "482913",
                status: .active,
                members: [
                    me,
                    ArenaMember(name: "Priya Shah", currentSpend: 188, lastSyncedAt: now),
                    ArenaMember(name: "Tom Okafor", currentSpend: 341, lastSyncedAt: now),
                    ArenaMember(name: "Ellie Clarke", currentSpend: 412, exceededAt: days(-2), lastSyncedAt: now)
                ]
            ),
            Arena(
                name: "No Pret Club",
                mode: .viceStreak,
                targetAmount: 0,
                stakeAmount: 5,
                viceCategory: .coffee,
                startDate: days(-5),
                endDate: days(16),
                joinCode: "715204",
                status: .active,
                members: [
                    ArenaMember(name: currentUser.name, isCurrentUser: true, currentSpend: 0, lastSyncedAt: now),
                    ArenaMember(name: "Sam Hughes", currentSpend: 0, lastSyncedAt: now),
                    ArenaMember(name: "Aisha Rahman", currentSpend: 4.2, isEliminated: true, exceededAt: days(-1), lastSyncedAt: now)
                ]
            ),
            Arena(
                name: "Summer Holiday Fund",
                mode: .savingsSprint,
                targetAmount: 500,
                stakeAmount: 20,
                startDate: days(-40),
                endDate: days(-1),
                joinCode: "306158",
                status: .active,
                members: [
                    ArenaMember(name: currentUser.name, isCurrentUser: true, currentSavings: 520, targetReachedAt: days(-4), lastSyncedAt: now),
                    ArenaMember(name: "Jack Murphy", currentSavings: 455, lastSyncedAt: now),
                    ArenaMember(name: "Priya Shah", currentSavings: 500, targetReachedAt: days(-2), lastSyncedAt: now)
                ]
            )
        ]
    }
}
