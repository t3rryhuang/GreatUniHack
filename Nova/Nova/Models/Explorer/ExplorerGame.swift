import Foundation

// Nova Explorer: Manchester. Pure game data and rules (no UI, no 3D).
// Fairness (F1-F8) is built into ExplorerEconomy: savings XP comes from progress to
// the player's OWN goal and streaks (never £ amounts), every source has a daily cap,
// and coins can only be earned in the game, never bought.

enum ExplorerZone: String, Codable, CaseIterable, Identifiable, Sendable {
    case venue, piccadilly, tramStop, northernQuarter, park

    var id: String { rawValue }

    var title: String {
        switch self {
        case .venue: "Nancy Rothwell Building"
        case .piccadilly: "Piccadilly Gardens"
        case .tramStop: "Metrolink stop"
        case .northernQuarter: "Northern Quarter"
        case .park: "Community Park"
        }
    }

    /// Where the player appears when travelling here (x, z in metres).
    var spawn: SIMD2<Float> {
        switch self {
        case .venue: SIMD2(0, 2)
        case .piccadilly: SIMD2(0, 34)
        case .tramStop: SIMD2(28, 34)
        case .northernQuarter: SIMD2(-26, 38)
        case .park: SIMD2(0, 66)
        }
    }

    /// Rough area used to name the zone the player is standing in.
    static func at(_ p: SIMD2<Float>) -> ExplorerZone {
        if p.y < 14 { return .venue }
        if p.y > 62 { return .park }
        if p.x > 18 { return .tramStop }
        if p.x < -16 { return .northernQuarter }
        return .piccadilly
    }
}

/// What happens when you talk to an NPC.
enum ExplorerActivity: Hashable, Sendable {
    case stylist
    case budgetHackathon
    case scamSpotter
    case tramTicket
    case marketplace
    case communityPark
    /// A Money Quest chapter, played as this NPC's quest (the existing levels).
    case moneyQuest(chapter: Int)
}

struct ExplorerNPC: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let role: String
    let position: SIMD2<Float>
    let activity: ExplorerActivity
    let look: AvatarLook
    let line: String

    var questID: String? {
        switch activity {
        case .stylist, .communityPark: nil
        case .budgetHackathon: "budget"
        case .scamSpotter: "scam"
        case .tramTicket: "tram"
        case .marketplace: "market"
        case .moneyQuest(let chapter): "mq\(chapter)"
        }
    }
}

enum ExplorerWorld {
    static func look(_ hair: HairStyle, _ hairColour: AvatarColour, _ top: TopStyle, _ topColour: AvatarColour, skin: SkinTone, accessory: Accessory = .none) -> AvatarLook {
        var l = AvatarLook()
        l.hair = hair; l.hairColour = hairColour; l.top = top; l.topColour = topColour; l.skin = skin; l.accessory = accessory
        l.bottomColour = .black
        return l
    }

    /// Fictional characters. The Money Quest NPCs host the existing chapters.
    static let npcs: [ExplorerNPC] = [
        ExplorerNPC(id: "remi", name: "Remi", role: "Stylist", position: SIMD2(-4, -1), activity: .stylist,
                    look: look(.afro, .pink, .jacket, .yellow, skin: .tone5, accessory: .glasses),
                    line: "Fancy a new look? I'm your stylist!"),
        ExplorerNPC(id: "priya", name: "Priya", role: "Hackathon lead", position: SIMD2(6, -4), activity: .budgetHackathon,
                    look: look(.long, .black, .hoodie, .teal, skin: .tone4),
                    line: "Our team has £60. Can you help split it?"),
        ExplorerNPC(id: "sam", name: "Sam", role: "Sponsor desk", position: SIMD2(10, 4), activity: .scamSpotter,
                    look: look(.short, .brown, .jumper, .navy, skin: .tone2, accessory: .cap),
                    line: "Sponsors left some offers. Which are safe?"),
        ExplorerNPC(id: "kemi", name: "Kemi", role: "Budget mentor", position: SIMD2(-9, 5), activity: .moneyQuest(chapter: 1),
                    look: look(.braids, .black, .tshirt, .orange, skin: .tone6),
                    line: "Needs, wants and your first budget. Ready?"),
        ExplorerNPC(id: "dev", name: "Dev", role: "Payslip helper", position: SIMD2(-11, -5), activity: .moneyQuest(chapter: 2),
                    look: look(.buzz, .black, .jacket, .grey, skin: .tone4, accessory: .headphones),
                    line: "Got your first payslip? Let's read it."),
        ExplorerNPC(id: "ade", name: "Ade", role: "Bank buddy", position: SIMD2(-6, 40), activity: .moneyQuest(chapter: 3),
                    look: look(.short, .black, .hoodie, .green, skin: .tone5),
                    line: "Current account or savings account?"),
        ExplorerNPC(id: "maya", name: "Maya", role: "Saver", position: SIMD2(7, 44), activity: .moneyQuest(chapter: 4),
                    look: look(.bun, .brown, .jumper, .pink, skin: .tone2),
                    line: "Want to see interest grow?"),
        ExplorerNPC(id: "lou", name: "Lou", role: "Tram guide", position: SIMD2(30, 38), activity: .tramTicket,
                    look: look(.short, .grey, .jacket, .yellow, skin: .tone1, accessory: .cap),
                    line: "Single, day or weekly ticket? Let's work it out."),
        ExplorerNPC(id: "fin", name: "Fin", role: "Phone shop", position: SIMD2(34, 46), activity: .moneyQuest(chapter: 8),
                    look: look(.curly, .orange, .tshirt, .blue, skin: .tone1),
                    line: "Free trials and phone contracts: what's the catch?"),
        ExplorerNPC(id: "zee", name: "Zee", role: "Market trader", position: SIMD2(-24, 44), activity: .marketplace,
                    look: look(.long, .purple, .hoodie, .white, skin: .tone3),
                    line: "£25 for the week. Needs first!"),
        ExplorerNPC(id: "vic", name: "Vic", role: "Scam warden", position: SIMD2(-30, 52), activity: .moneyQuest(chapter: 7),
                    look: look(.buzz, .grey, .jacket, .black, skin: .tone3, accessory: .glasses),
                    line: "Easy money offers? Let's spot the traps."),
        ExplorerNPC(id: "bea", name: "Bea", role: "Borrowing coach", position: SIMD2(-20, 32), activity: .moneyQuest(chapter: 5),
                    look: look(.long, .yellow, .jacket, .red, skin: .tone2),
                    line: "APR, overdrafts, buy now pay later. Let's talk."),
        ExplorerNPC(id: "jo", name: "Jo", role: "Park ranger", position: SIMD2(-6, 70), activity: .communityPark,
                    look: look(.short, .brown, .jacket, .green, skin: .tone4, accessory: .beanie),
                    line: "Help Manchester build the Community Park!"),
        ExplorerNPC(id: "ola", name: "Ola", role: "Credit file guide", position: SIMD2(8, 72), activity: .moneyQuest(chapter: 6),
                    look: look(.afro, .black, .hoodie, .blue, skin: .tone6),
                    line: "What's on a credit file? Let's find out."),
        ExplorerNPC(id: "nia", name: "Nia", role: "Moving-out helper", position: SIMD2(14, 66), activity: .moneyQuest(chapter: 9),
                    look: look(.bun, .black, .tshirt, .purple, skin: .tone5),
                    line: "Rent, deposits and bills: let's plan a move."),
        ExplorerNPC(id: "tom", name: "Tom", role: "Help desk", position: SIMD2(-14, 66), activity: .moneyQuest(chapter: 10),
                    look: look(.curly, .brown, .jumper, .teal, skin: .tone2),
                    line: "When money's tight, there's help."),
    ]
}

// MARK: Progress

struct ExplorerProgress: Codable, Hashable, Sendable {
    var look = AvatarLook()
    var avatarConfirmed = false
    var xp = 0
    var coins = 0
    var xpByDay: [String: Int] = [:]
    var completedQuests: [String] = []
    /// Savings rewards already given (keys from ExplorerEconomy.savingsRewards).
    var claimedRewards: [String] = []
    var ownedCosmetics: [String] = []
    var equippedCosmetic: String?
    var badges: [String] = []
    var parkPointsByDay: [String: Int] = [:]
    var parkContributed = 0
    /// Park points earned from quests and not yet given to the park.
    var parkTokens = 0
    var thirdPerson = true

    init() {}

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        look = (try? c.decodeIfPresent(AvatarLook.self, forKey: .look)) ?? AvatarLook()
        avatarConfirmed = (try? c.decodeIfPresent(Bool.self, forKey: .avatarConfirmed)) ?? false
        xp = (try? c.decodeIfPresent(Int.self, forKey: .xp)) ?? 0
        coins = (try? c.decodeIfPresent(Int.self, forKey: .coins)) ?? 0
        xpByDay = (try? c.decodeIfPresent([String: Int].self, forKey: .xpByDay)) ?? [:]
        completedQuests = (try? c.decodeIfPresent([String].self, forKey: .completedQuests)) ?? []
        claimedRewards = (try? c.decodeIfPresent([String].self, forKey: .claimedRewards)) ?? []
        ownedCosmetics = (try? c.decodeIfPresent([String].self, forKey: .ownedCosmetics)) ?? []
        equippedCosmetic = try? c.decodeIfPresent(String.self, forKey: .equippedCosmetic)
        badges = (try? c.decodeIfPresent([String].self, forKey: .badges)) ?? []
        parkPointsByDay = (try? c.decodeIfPresent([String: Int].self, forKey: .parkPointsByDay)) ?? [:]
        parkContributed = (try? c.decodeIfPresent(Int.self, forKey: .parkContributed)) ?? 0
        parkTokens = (try? c.decodeIfPresent(Int.self, forKey: .parkTokens)) ?? 0
        thirdPerson = (try? c.decodeIfPresent(Bool.self, forKey: .thirdPerson)) ?? true
    }

    var level: Int { ExplorerEconomy.level(xp: xp) }
    func xpToday(_ now: Date = .now) -> Int { xpByDay[MoneyQuestRules.dayKey(now)] ?? 0 }
    func parkPointsToday(_ now: Date = .now) -> Int { parkPointsByDay[MoneyQuestRules.dayKey(now)] ?? 0 }
}

struct ExplorerReward: Hashable, Sendable, Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let xp: Int
    let coins: Int
}

// MARK: Economy

enum ExplorerEconomy {
    static let questXP = 60
    static let questCoins = 20
    static let moneyQuestXP = 40
    static let moneyQuestCoins = 10
    static let replayXP = 10
    /// F7: one cap for every XP source, so free time or money can't run away with it.
    static let dailyXPCap = 300
    static let savingsMilestones: [Double] = [0.25, 0.5, 0.75, 1.0]
    static let savingsMilestoneXP = 80
    static let savingsMilestoneCoins = 20
    static let streakMonthXP = 50
    static let streakMonthCoins = 10
    static let xpPerLevel = 250
    /// Park points a player can give per day (anyone can help, whatever their money).
    static let dailyParkPoints = 3

    static func level(xp: Int) -> Int { 1 + max(0, xp) / xpPerLevel }

    /// Real-to-game sync (F1, F3): XP for reaching 25/50/75/100% of the player's OWN
    /// Piggy Bank goal and for each month of the saving streak. A £25 goal and a £1,000
    /// goal earn exactly the same. Each reward is given once.
    static func savingsRewards(piggy: PiggyBank?, savingStreakMonths: Int, hardshipScale: Double, claimed: [String]) -> [ExplorerReward] {
        var rewards: [ExplorerReward] = []
        if let piggy {
            let progress = PiggyRules.progress(piggy, scale: hardshipScale)
            let goalKey = "\(piggy.goalName.lowercased())|\(Int(piggy.goalAmount * 100))"
            for milestone in savingsMilestones where progress >= milestone {
                let key = "goal:\(goalKey):\(Int(milestone * 100))"
                if !claimed.contains(key) {
                    rewards.append(ExplorerReward(key: key, title: "Piggy Bank \(Int(milestone * 100))% of your goal",
                                                  xp: savingsMilestoneXP, coins: savingsMilestoneCoins))
                }
            }
        }
        // One reward for the longest streak reached so far (capped at 6 months), not one per month.
        let months = min(max(savingStreakMonths, 0), 6)
        let claimedMonths = claimed.compactMap { $0.hasPrefix("streak:") ? Int($0.dropFirst(7)) : nil }.max() ?? 0
        if months > claimedMonths {
            rewards.append(ExplorerReward(key: "streak:\(months)", title: "\(months)-month saving streak", xp: streakMonthXP, coins: streakMonthCoins))
        }
        return rewards
    }

    /// Adds XP within today's cap; returns the XP actually given.
    static func grant(_ xp: Int, coins: Int, to progress: inout ExplorerProgress, now: Date = .now) -> Int {
        let day = MoneyQuestRules.dayKey(now)
        let room = max(0, dailyXPCap - (progress.xpByDay[day] ?? 0))
        let given = min(max(0, xp), room)
        progress.xpByDay[day, default: 0] += given
        progress.xp += given
        // Coins scale with the XP actually given, so they're capped too.
        progress.coins += xp > 0 ? Int((Double(coins) * Double(given) / Double(xp)).rounded()) : 0
        return given
    }

    /// XP and coins for finishing a quest; full reward the first time, a little for replays.
    static func questReward(questID: String, isMoneyQuest: Bool, progress: ExplorerProgress) -> (xp: Int, coins: Int) {
        if progress.completedQuests.contains(questID) { return (replayXP, 0) }
        return isMoneyQuest ? (moneyQuestXP, moneyQuestCoins) : (questXP, questCoins)
    }
}

// MARK: Quests

/// Example fares for the game, NOT real Bee Network prices (verify before showing as real).
enum TramFares {
    static let single = 2.00
    static let day = 5.00
    static let week = 17.50
}

enum ExplorerQuestRules {
    // The Budgeting Hackathon: split £60 between snacks, tools and emergency savings.
    static let hackathonBudget = 60.0

    static func checkBudget(snacks: Double, tools: Double, savings: Double) -> (passed: Bool, notes: [String]) {
        var notes: [String] = []
        let total = snacks + tools + savings
        if abs(total - hackathonBudget) > 0.5 { notes.append("Your split adds up to \(total.gbpWhole). It needs to be exactly \(hackathonBudget.gbpWhole).") }
        if snacks <= 0 { notes.append("A team needs to eat. Put something towards snacks.") }
        if tools <= 0 { notes.append("You need some hardware to build your project.") }
        if savings < hackathonBudget * 0.1 { notes.append("Keep at least 10% (\((hackathonBudget * 0.1).gbpWhole)) as emergency savings, in case something breaks.") }
        let passed = notes.isEmpty
        if passed { notes.append("Great split! You covered the basics and kept \(savings.gbpWhole) back for surprises.") }
        return (passed, notes)
    }

    // The Scam Spotter
    struct Offer: Identifiable, Hashable, Sendable {
        let id: Int
        let text: String
        let isSafe: Bool
        let explanation: String
        let isMoneyMule: Bool
    }

    static let sponsorOffers: [Offer] = [
        Offer(id: 0, text: "Free pizza for every team that demos by 6pm.", isSafe: true,
              explanation: "Safe: a real perk, and nobody asks for your details or money.", isMoneyMule: false),
        Offer(id: 1, text: "Win a laptop! Just send us your bank login to enter.", isSafe: false,
              explanation: "Scam: no real company asks for your bank login. Ever.", isMoneyMule: false),
        Offer(id: 2, text: "Earn £300 by letting us move some money through your bank account.", isSafe: false,
              explanation: "Money mule trap: moving money for someone else is a crime and can get your account closed.", isMoneyMule: true),
        Offer(id: 3, text: "Sponsor workshop at 3pm: how to build a banking app.", isSafe: true,
              explanation: "Safe: free learning, nothing to pay or share.", isMoneyMule: false),
        Offer(id: 4, text: "Pay £20 to unlock a 'guaranteed winner' prize.", isSafe: false,
              explanation: "Scam: you never have to pay to claim a real prize.", isMoneyMule: false),
    ]

    /// Pass: at most one mistake, and the money-mule trap must be spotted.
    static func checkScams(_ answers: [Int: Bool]) -> (passed: Bool, correct: Int, spottedMule: Bool) {
        let correct = sponsorOffers.filter { answers[$0.id] == $0.isSafe }.count
        let mule = sponsorOffers.first(where: \.isMoneyMule).map { answers[$0.id] == false } ?? true
        return (correct >= sponsorOffers.count - 1 && mule, correct, mule)
    }

    // The Tram Ticket Challenge
    struct TramTrip: Identifiable, Hashable, Sendable {
        let id: Int
        let story: String
        let trips: Int
        let days: Int
    }

    enum Ticket: String, CaseIterable, Identifiable, Sendable {
        case singles, dayPasses, weekly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .singles: "Single tickets"
            case .dayPasses: "Day passes"
            case .weekly: "A weekly pass"
            }
        }
    }

    static let tramTrips: [TramTrip] = [
        TramTrip(id: 0, story: "You go to college and back once this week (2 trips, 1 day).", trips: 2, days: 1),
        TramTrip(id: 1, story: "Saturday: town, the cinema, then home (4 trips, 1 day).", trips: 4, days: 1),
        TramTrip(id: 2, story: "College every weekday and back (10 trips, 5 days).", trips: 10, days: 5),
    ]

    static func cost(_ ticket: Ticket, for trip: TramTrip) -> Double {
        switch ticket {
        case .singles: Double(trip.trips) * TramFares.single
        case .dayPasses: Double(trip.days) * TramFares.day
        case .weekly: TramFares.week
        }
    }

    static func cheapest(for trip: TramTrip) -> Ticket {
        Ticket.allCases.min { cost($0, for: trip) < cost($1, for: trip) } ?? .singles
    }

    // Needs vs Wants Marketplace
    struct MarketItem: Identifiable, Hashable, Sendable {
        let id: Int
        let name: String
        let price: Double
        let isNeed: Bool
        let symbol: String
    }

    static let marketBudget = 25.0
    static let marketItems: [MarketItem] = [
        MarketItem(id: 0, name: "Bus pass top-up", price: 10, isNeed: true, symbol: "bus.fill"),
        MarketItem(id: 1, name: "Lunch for the week", price: 9, isNeed: true, symbol: "takeoutbag.and.cup.and.straw.fill"),
        MarketItem(id: 2, name: "Phone bill share", price: 5, isNeed: true, symbol: "iphone"),
        MarketItem(id: 3, name: "Limited-edition trainers", price: 60, isNeed: false, symbol: "shoe.fill"),
        MarketItem(id: 4, name: "Game skin", price: 8, isNeed: false, symbol: "gamecontroller.fill"),
        MarketItem(id: 5, name: "Bubble tea", price: 4, isNeed: false, symbol: "cup.and.saucer.fill"),
    ]

    /// Pass: every need bought and the basket within budget (a small want is fine if it fits).
    static func checkMarket(_ basket: Set<Int>) -> (passed: Bool, total: Double, missingNeeds: [String]) {
        let items = marketItems.filter { basket.contains($0.id) }
        let total = items.reduce(0) { $0 + $1.price }
        let missing = marketItems.filter { $0.isNeed && !basket.contains($0.id) }.map(\.name)
        return (missing.isEmpty && total <= marketBudget, total, missing)
    }
}

// MARK: Community Park

struct ParkStatus: Codable, Hashable, Sendable {
    var total: Int
    var contributors: Int

    var stage: ParkStage { ParkStage.from(total: total) }
}

enum ParkStage: Int, CaseIterable, Comparable, Sendable {
    case emptyLot, benches, trees, fountain, skatepark

    static func < (a: ParkStage, b: ParkStage) -> Bool { a.rawValue < b.rawValue }

    /// Community points needed to reach each stage.
    var threshold: Int { [0, 500, 1_500, 3_000, 6_000][rawValue] }
    var title: String { ["Empty lot", "Benches", "Trees", "Fountain", "Skatepark"][rawValue] }
    var next: ParkStage? { ParkStage(rawValue: rawValue + 1) }

    static func from(total: Int) -> ParkStage {
        allCases.last { total >= $0.threshold } ?? .emptyLot
    }
}

// MARK: Cosmetics

struct Cosmetic: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let cost: Int
    let symbol: String
    /// Unlocked by behaviour (badges), never by money.
    let requiresBadge: String?
}

enum CosmeticCatalogue {
    static let all: [Cosmetic] = [
        Cosmetic(id: "backpack", title: "Backpack", cost: 40, symbol: "backpack.fill", requiresBadge: nil),
        Cosmetic(id: "scarf", title: "NatWest purple scarf", cost: 60, symbol: "wind", requiresBadge: nil),
        Cosmetic(id: "crown", title: "Saver's crown", cost: 80, symbol: "crown.fill", requiresBadge: "saver"),
        Cosmetic(id: "halo", title: "Scam-spotter halo", cost: 50, symbol: "shield.lefthalf.filled", requiresBadge: "scam"),
    ]

    static func isUnlocked(_ item: Cosmetic, progress: ExplorerProgress) -> Bool {
        item.requiresBadge.map { progress.badges.contains($0) } ?? true
    }

    /// Only catalogue items can be equipped (validation for saved data and the wardrobe).
    static func validate(_ id: String?) -> String? {
        guard let id, all.contains(where: { $0.id == id }) else { return nil }
        return id
    }
}

enum Emote: String, CaseIterable, Identifiable, Sendable {
    case wave, cheer, dance
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .wave: "hand.wave.fill"
        case .cheer: "hands.clap.fill"
        case .dance: "figure.dance"
        }
    }
}
