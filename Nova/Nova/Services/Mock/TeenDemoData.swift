import Foundation

/// Demo data for Teen A and Teen B. Both are generated from the same random seed with
/// the same habits; only the amounts are scaled to each teen's money. This is what lets
/// the fairness check show that the score rewards behaviour, not wealth.
extension MockDataFactory {
    struct TeenSetup {
        let name: String
        let email: String
        let pocketMoneyWeekly: Double
        let wagesWeekly: Double
        /// Everyday spending scale (Teen B = 1).
        let spendScale: Double
        let bill: (name: String, amount: Double, partner: String, relationship: String)
        let loan: (purpose: String, amount: Double, lender: String, relationship: String)
        let promiseWeekly: Double
        let goal: (name: String, amount: Double, startingSaved: Double)
        let savingsBalance: Double
        let monthlySaverTransfer: Double
        let poorHabits: Bool
    }

    static func teenSetup(_ profile: DemoProfile) -> TeenSetup {
        switch profile {
        case .teenA:
            TeenSetup(name: "Riley Chen", email: "riley.chen@example.com", pocketMoneyWeekly: 15, wagesWeekly: 0, spendScale: 0.13,
                      bill: ("Music app share", 3, "Big sister", "Sister, 22"),
                      loan: ("Phone case", 5, "Grandma", "Grandparent"),
                      promiseWeekly: 1, goal: ("Gig ticket", 25, 10), savingsBalance: 40, monthlySaverTransfer: 2, poorHabits: false)
        case .teenB, .adult:
            TeenSetup(name: "Jamie Patel", email: "jamie.patel@example.com", pocketMoneyWeekly: 10, wagesWeekly: 92, spendScale: 1,
                      bill: ("Phone bill share", 10, "Mum", "Parent"),
                      loan: ("A console", 200, "Mum", "Parent"),
                      promiseWeekly: 5, goal: ("Festival ticket", 120, 0), savingsBalance: 265, monthlySaverTransfer: 20, poorHabits: false)
        case .teenBPoorHabits:
            TeenSetup(name: "Jamie Patel", email: "jamie.patel@example.com", pocketMoneyWeekly: 10, wagesWeekly: 92, spendScale: 1,
                      bill: ("Phone bill share", 10, "Mum", "Parent"),
                      loan: ("A console", 200, "Mum", "Parent"),
                      promiseWeekly: 5, goal: ("Festival ticket", 120, 0), savingsBalance: 20, monthlySaverTransfer: 0, poorHabits: true)
        }
    }

    static let teenName = "Jamie Patel"
    static let teenEmail = "jamie.patel@example.com"

    /// 17 years and 7 months old, so the 18th birthday is about 5 months away.
    static func teenDateOfBirth(now: Date = .now) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(byAdding: DateComponents(year: -17, month: -7), to: calendar.startOfDay(for: now)) ?? now
    }

    // MARK: Family (loan, shared bill)

    static func teenFamily(_ profile: DemoProfile = .teenB, now: Date = .now) -> FamilyState {
        let setup = teenSetup(profile)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        let approved = calendar.date(byAdding: .day, value: -75, to: today) ?? today
        let schedule = FamilyLoan.schedule(amount: setup.loan.amount, instalments: 4, from: approved, calendar: calendar)
        let loanPayments = schedule.enumerated().map { index, payment -> FamilyPayment in
            var p = payment
            if p.due <= today {
                // Good habits: paid the day before. Poor habits: first one 9 days late, second missed.
                p.paid = setup.poorHabits ? (index == 0 ? calendar.date(byAdding: .day, value: 9, to: p.due) : nil)
                                          : calendar.date(byAdding: .day, value: -1, to: p.due)
            }
            return p
        }
        let billStart = calendar.date(byAdding: .month, value: -5, to: today) ?? today
        var bill = SharedBill(name: setup.bill.name, amount: setup.bill.amount, dayOfMonth: 12, partnerName: setup.bill.partner,
                              relationship: setup.bill.relationship, startDate: calendar.dateInterval(of: .month, for: billStart)?.start ?? billStart,
                              payments: [])
        for (index, cycle) in bill.cycles(now: now, calendar: calendar).enumerated() where cycle.due <= today {
            if setup.poorHabits && index % 3 == 2 { continue } // missed
            let delay = setup.poorHabits && index % 3 == 1 ? 6 : 0
            bill.payments.append(FamilyPayment(due: cycle.due, amount: cycle.amount, paid: calendar.date(byAdding: .day, value: delay, to: cycle.due)))
        }
        return FamilyState(
            loans: [FamilyLoan(purpose: setup.loan.purpose, amount: setup.loan.amount, instalments: 4, lenderName: setup.loan.lender,
                               relationship: setup.loan.relationship, requestedAt: calendar.date(byAdding: .day, value: -1, to: approved) ?? approved,
                               approvedAt: approved, status: .approved, payments: loanPayments)],
            bills: [bill]
        )
    }

    // MARK: Piggy Bank

    static func teenPiggy(_ profile: DemoProfile = .teenB, now: Date = .now) -> PiggyBank {
        let setup = teenSetup(profile)
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -70, to: calendar.startOfDay(for: now)) ?? now
        var promise = PromiseToMyself(amount: setup.promiseWeekly, weekday: 6, startDate: start)
        var deposits: [PiggyDeposit] = setup.goal.startingSaved > 0 ? [PiggyDeposit(date: start, amount: setup.goal.startingSaved)] : []
        if !setup.poorHabits {
            for cycle in promise.cycles(now: now) where cycle.due < calendar.startOfDay(for: now) {
                promise.payments.append(FamilyPayment(due: cycle.due, amount: setup.promiseWeekly, paid: cycle.due))
                deposits.append(PiggyDeposit(date: cycle.due, amount: setup.promiseWeekly, isPromise: true))
            }
        }
        return PiggyBank(goalName: setup.goal.name, goalAmount: setup.goal.amount,
                         targetDate: calendar.date(byAdding: .month, value: 4, to: now),
                         saved: deposits.reduce(0) { $0 + $1.amount }, deposits: deposits, promise: promise)
    }

    // MARK: Transactions

    static let teenHabits: [(SpendingCategory, [String], ClosedRange<Double>, Double)] = [
        (.dining, ["Greggs", "Subway", "Nando's", "McDonald's", "Chicken Cottage"], 3...11, 3.2),
        (.transport, ["Bee Network Bus", "Metrolink"], 1...2.8, 4.5),
        (.coffee, ["Costa Coffee", "Starbucks"], 2.6...4.4, 1.0),
        (.entertainment, ["Vue Cinema", "Steam", "Odeon Cinema", "Hollywood Bowl"], 5...16, 0.6),
        (.shopping, ["Primark", "JD Sports", "Amazon", "H&M"], 6...35, 0.5),
        (.groceries, ["Tesco Express", "Co-op"], 2...9, 1.0)
    ]

    /// Six months for a teen. The random choices come from one seed for every profile and
    /// the amounts are scaled, so Teen A and Teen B make the same choices with different money.
    static func teenTransactions(_ profile: DemoProfile = .teenB, months: Int = 6, now: Date = .now, seed: UInt64 = 1717) -> [Transaction] {
        let setup = teenSetup(profile)
        var rng = SeededGenerator(seed: seed)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .month, value: -months, to: today) else { return [] }
        func money(_ value: Double) -> Double { (value * 100).rounded() / 100 }

        var result: [Transaction] = []
        var day = start
        var weekIndex = 0
        while day <= today {
            let weekday = calendar.component(.weekday, from: day)
            let dayOfMonth = calendar.component(.day, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            if weekday == 6 {
                weekIndex += 1
                let wobble = Double.random(in: 0.92...1.08, using: &rng)
                if setup.wagesWeekly > 0 {
                    result.append(Transaction(date: at(day, hour: 9, calendar), description: "Wages - Cafe job payroll", amount: money(setup.wagesWeekly * wobble), category: .income))
                }
            }
            if weekday == 7 {
                result.append(Transaction(date: at(day, hour: 10, calendar), description: "Pocket money income from family", amount: setup.pocketMoneyWeekly, category: .income))
            }
            if dayOfMonth == 1, setup.monthlySaverTransfer > 0 {
                result.append(Transaction(date: at(day, hour: 8, calendar), description: "Transfer to Flexible Saver", amount: -setup.monthlySaverTransfer, category: .transfer))
            }
            for (category, names, range, perWeek) in teenHabits {
                var chance = perWeek / 7
                if isWeekend && (category == .entertainment || category == .shopping) { chance *= 1.8 }
                if !isWeekend && category == .transport { chance *= 1.2 }
                let roll = Double.random(in: 0...1, using: &rng)
                let name = names[Int.random(in: 0..<names.count, using: &rng)]
                var amount = Double.random(in: range, using: &rng)
                let hour = hourFor(category, rng: &rng)
                // Poor habits: occasional big splurges.
                if setup.poorHabits && category == .shopping && weekIndex % 3 == 0 { amount *= 3 }
                if roll < min(chance, 1) {
                    result.append(Transaction(date: at(day, hour: hour, calendar), description: name, amount: -money(amount * setup.spendScale), category: category))
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        // Family and piggy payments, matching the Family and Piggy Bank screens.
        let family = teenFamily(profile, now: now)
        for loan in family.loans {
            if let approved = loan.approvedAt {
                result.append(Transaction(date: at(approved, hour: 19, calendar), description: "Transfer from \(loan.lenderName) - \(loan.purpose.lowercased()) loan", amount: loan.amount, category: .transfer))
                result.append(Transaction(date: at(approved, hour: 20, calendar), description: loan.purpose, amount: -loan.amount, category: .shopping))
            }
            for payment in loan.payments {
                if let paid = payment.paid {
                    result.append(Transaction(date: at(paid, hour: 18, calendar), description: "Transfer to \(loan.lenderName) - loan repayment", amount: -payment.amount, category: .transfer))
                }
            }
        }
        for bill in family.bills {
            for payment in bill.payments {
                if let paid = payment.paid, paid >= start {
                    result.append(Transaction(date: at(paid, hour: 18, calendar), description: "Transfer to \(bill.partnerName) - \(bill.name.lowercased())", amount: -payment.amount, category: .transfer))
                }
            }
        }
        for deposit in teenPiggy(profile, now: now).deposits {
            result.append(Transaction(date: at(deposit.date, hour: 17, calendar), description: deposit.isPromise ? "Transfer to Piggy Bank - promise to myself" : "Transfer to Piggy Bank",
                                      amount: -deposit.amount, category: .transfer))
        }
        return result.sorted { $0.date > $1.date }
    }

    // MARK: Readiness and game starting progress

    /// The same habits for Teen A and Teen B: streak, quests, what-ifs and Money Quest levels.
    static func readinessSeed(_ profile: DemoProfile, now: Date = .now) -> ReadinessProgress {
        var p = ReadinessProgress()
        switch profile {
        case .adult:
            p.streak = 9; p.longestStreak = 31; p.questsCompleted = 40; p.whatIfs = 2
        case .teenA, .teenB:
            // The shield saved a 21-day streak two days ago; completing today's quest makes it 23.
            p.streak = 22; p.longestStreak = 22; p.questsCompleted = 22; p.whatIfs = 1; p.moneyQuestLevels = 2
            let shieldDay = Calendar.current.date(byAdding: .day, value: -2, to: Calendar.current.startOfDay(for: now)) ?? now
            p.shieldMonths = [ReadinessRules.monthKey(shieldDay)]
            p.lastShieldEvent = ShieldEvent(date: shieldDay, savedStreak: 21)
        case .teenBPoorHabits:
            p.streak = 2; p.longestStreak = 6; p.questsCompleted = 5
        }
        return p
    }
}
