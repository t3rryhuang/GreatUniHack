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

    // MARK: Arenas

    static let friendNames = ["Priya Shah", "Tom Okafor", "Ellie Clarke", "Sam Hughes", "Aisha Rahman", "Jack Murphy"]

    static func demoArenas(currentUser: UserProfile, now: Date = .now) -> [Arena] {
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
