import Observation
import SwiftUI

/// App-wide state shared by every screen: the session, the user's transactions,
/// the derived summary, the plan and the savings account.
/// Replaces the original ArenaContext, UserDataContext, ProContext and SolanaContext.
@Observable
final class AppModel {
    enum Phase: Equatable { case launching, signedOut, onboarding, ready }

    let services: ServiceContainer

    private(set) var phase: Phase = .launching
    private(set) var user: UserProfile?
    private(set) var transactions: [Transaction] = []
    private(set) var summary: FinancialSummary = .empty
    private(set) var plan: Plan = .free
    private(set) var savingsAccount: SavingsAccount?
    private(set) var dataVersion = 0
    /// The latest Readiness Score and the data behind it.
    private(set) var readiness: ReadinessSnapshot?
    private(set) var readinessProgress = ReadinessProgress()
    /// Family loans and shared bills (Teen mode).
    private(set) var family = FamilyState()
    /// Money Quest points, badges and completed levels.
    private(set) var game = GameProgress()
    /// Nova Explorer save game and the shared Community Park.
    private(set) var explorer = ExplorerProgress()
    private(set) var park: ParkStatus?
    var errorMessage: String?

    /// Presentation state for app-wide sheets.
    var showUpgrade = false
    var showChat = false
    var showBriefing = false
    var showAddTransaction = false
    /// Shown once when a teen turns 18 and moves to the full app.
    var showEighteenWelcome = false
    var lockedFeature: ProFeature?

    /// Every feature is unlocked for everyone: there is no paid tier or free trial.
    /// (The Pro gating code is kept so a paid plan could be switched back on later.)
    static let allFeaturesUnlocked = true
    var isPro: Bool { Self.allFeaturesUnlocked || plan == .pro }
    var hasData: Bool { !transactions.isEmpty }

    // MARK: Life stage

    private static let demoStageKey = "nova.demoStage"

    /// Demo override from Profile > Demo, so the stage can change without editing the birth date.
    private(set) var demoStageOverride: LifeStage? = UserDefaults.standard.string(forKey: AppModel.demoStageKey).flatMap(LifeStage.init(rawValue:))

    private static let demoProfileKey = "nova.demoProfile"

    /// The demo data set in use (Profile > Demo).
    private(set) var demoProfile: DemoProfile = UserDefaults.standard.string(forKey: AppModel.demoProfileKey).flatMap(DemoProfile.init(rawValue:)) ?? .adult

    /// Teen (16-17) or adult. The demo override wins over the date of birth.
    var stage: LifeStage { demoStageOverride ?? user?.stage ?? .adult }
    var isTeen: Bool { stage == .teen }

    /// Date of birth used for the graduation countdown. With the demo override
    /// and no real date, a demo 17-year-old's birthday is used.
    var effectiveDateOfBirth: Date? {
        if let dob = user?.dateOfBirth, LifeStage.from(dateOfBirth: dob) == stage { return dob }
        return isTeen ? MockDataFactory.teenDateOfBirth() : user?.dateOfBirth
    }

    /// The next 18th birthday, for teens.
    var eighteenthBirthday: Date? {
        guard isTeen, let dob = effectiveDateOfBirth else { return nil }
        return Calendar.current.date(byAdding: .year, value: 18, to: dob)
    }

    init(services: ServiceContainer) {
        self.services = services
    }

    func start() async {
        plan = services.subscription.plan
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        // Launch with `-NovaTeenDemo` to start as Jamie, 17, in Teen mode.
        // `-NovaTeenADemo` starts as Teen A (pocket money only).
        let teenProfile: DemoProfile? = arguments.contains("-NovaTeenADemo") ? .teenA : arguments.contains("-NovaTeenDemo") ? .teenB : nil
        if let teenProfile, services.auth.currentUser?.email != MockDataFactory.teenSetup(teenProfile).email || demoProfile != teenProfile {
            let setup = MockDataFactory.teenSetup(teenProfile)
            if (try? await services.auth.signIn(email: setup.email, password: "demo1234")) != nil {
                await services.auth.updateBank(.natwest)
                await services.auth.updateDateOfBirth(MockDataFactory.teenDateOfBirth())
                user = services.auth.currentUser
                await resetDemo(to: teenProfile)
            }
        // Launch with `-NovaDemo` to skip sign-in and onboarding (handy for demos and screenshots).
        } else if arguments.contains("-NovaDemo"), services.auth.currentUser == nil {
            if (try? await services.auth.signIn(email: "alex.taylor@example.com", password: "demo1234")) != nil {
                await services.auth.updateBank(.natwest)
                user = services.auth.currentUser
                await resetDemo(to: .adult)
            }
        }
        #endif
        guard let current = services.auth.currentUser else {
            phase = .signedOut
            return
        }
        user = current
        checkForEighteenthBirthday()
        await reloadData()
        phase = hasData ? .ready : .onboarding
    }

    // MARK: Turning 18

    private static let lastStageKey = "nova.lastStage"

    /// Teen mode ends on the 18th birthday: the next launch moves the user to the
    /// full app (their score and history carry over) and shows a welcome.
    private func checkForEighteenthBirthday() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: Self.lastStageKey).flatMap(LifeStage.init(rawValue:))
        let current = user?.stage ?? .adult
        if previous == .teen, current == .adult, demoStageOverride == nil { showEighteenWelcome = true }
        defaults.set(current.rawValue, forKey: Self.lastStageKey)
    }

    func setDateOfBirth(_ date: Date?) async {
        await services.auth.updateDateOfBirth(date)
        user = services.auth.currentUser
        UserDefaults.standard.set(stage.rawValue, forKey: Self.lastStageKey)
    }

    /// Demo: pretend today is the 18th birthday.
    func simulateEighteenthBirthday() async {
        let dob = Calendar.current.date(byAdding: .year, value: -18, to: .now)
        await services.auth.updateDateOfBirth(dob)
        user = services.auth.currentUser
        demoStageOverride = nil
        UserDefaults.standard.removeObject(forKey: Self.demoStageKey)
        UserDefaults.standard.set(LifeStage.adult.rawValue, forKey: Self.lastStageKey)
        await reloadData()
        showEighteenWelcome = true
    }

    // MARK: Session

    func didSignIn(_ profile: UserProfile) async {
        user = profile
        await reloadData()
        phase = hasData ? .ready : .onboarding
    }

    func finishOnboarding(bank: Bank) async {
        await services.auth.updateBank(bank)
        user = services.auth.currentUser
        phase = .ready
    }

    func signOut() async {
        services.voice.stopSpeaking()
        await services.auth.signOut()
        user = nil
        demoStageOverride = nil
        UserDefaults.standard.removeObject(forKey: Self.demoStageKey)
        transactions = []
        summary = .empty
        phase = .signedOut
    }

    // MARK: Data

    func reloadData() async {
        do {
            async let txns = services.transactions.fetchTransactions()
            async let account = services.savings.account()
            savingsAccount = try await account
            apply(try await txns)
        } catch {
            errorMessage = error.localizedDescription
        }
        family = await services.family.state()
        game = await services.game.progress()
        await refreshReadiness()
    }

    func apply(_ newTransactions: [Transaction]) {
        transactions = newTransactions
        summary = FinancialSummary.make(from: newTransactions, savingsBalance: savingsAccount?.balance ?? 0)
        dataVersion += 1
    }

    /// Onboarding's "Use demo data": every demo data set for the current stage.
    func loadDemoData() async throws {
        await resetDemoServices(for: DemoProfile.default(for: stage))
        await reloadData()
    }

    func importStatement(_ data: Data, type: ImportFileType) async throws {
        apply(try await services.transactions.importStatement(data, type: type))
        await refreshReadiness()
    }

    func addTransaction(_ transaction: Transaction) async throws {
        try await services.transactions.add(transaction)
        apply(try await services.transactions.fetchTransactions())
        await refreshReadiness()
    }

    func deleteTransaction(_ id: UUID) async {
        try? await services.transactions.delete(id: id)
        apply(transactions.filter { $0.id != id })
        await refreshReadiness()
    }

    func clearAllData() async {
        try? await services.transactions.clearAll()
        apply([])
        phase = .onboarding
    }

    func refreshSavings() async {
        if let account = try? await services.savings.account() {
            savingsAccount = account
            summary = FinancialSummary.make(from: transactions, savingsBalance: account.balance)
            await refreshReadiness()
        }
    }

    // MARK: Readiness

    /// Recomputes the Readiness Score from the current data.
    func refreshReadiness() async {
        guard hasData else {
            readiness = nil
            return
        }
        let earliest = transactions.map(\.date).min() ?? .now
        let input = ReadinessInput(
            transactions: transactions,
            summary: summary,
            savingsBalance: savingsAccount?.balance ?? 0,
            familyPayments: isTeen ? family.scheduledPayments() + ReadinessRules.promisePayments(piggy, now: .now) : [],
            accountStart: min(user?.memberSince ?? .now, earliest),
            stage: stage,
            savingDeposits: ReadinessRules.savingDeposits(transactions, piggy: piggy),
            hardshipScale: hardshipScale
        )
        readiness = await services.readiness.evaluate(input)
        readinessProgress = await services.readiness.progress()
    }


    /// Counts a what-if, lesson or sandbox run towards Wisdom.
    func recordWisdom(_ event: WisdomEvent) async {
        readinessProgress = await services.readiness.record(event)
        await refreshReadiness()
    }

    /// Creates today's quest from today's predictions (once a day), then refreshes the score.
    func prepareQuest(predictions: [PredictionItem]) async {
        guard hasData, readiness?.quest == nil else { return }
        if await services.readiness.todaysQuest(predictions: predictions) != nil {
            await refreshReadiness()
        }
    }

    /// Demo: completes today's quest now so the demo doesn't have to wait a day.
    func completeQuestForDemo() async {
        readinessProgress = await services.readiness.completeTodaysQuest()
        await refreshReadiness()
    }

    func setVotingChecked(_ done: Bool) async {
        readinessProgress = await services.readiness.setVotingChecked(done)
    }

    func markReportPreviewed() async {
        readinessProgress = await services.readiness.markReportPreviewed()
    }

    func setWeeklyLimit(_ limit: Double?) async {
        readinessProgress = await services.readiness.setWeeklyLimit(limit)
        await refreshReadiness()
    }

    // MARK: Family

    /// Sends a loan request; the simulated adult approves it after a short delay,
    /// then the money arrives as a transfer.
    func requestFamilyLoan(purpose: String, amount: Double, instalments: Int, lenderName: String, relationship: String) async throws {
        let request = try await services.family.requestLoan(purpose: purpose, amount: amount, instalments: instalments,
                                                            lenderName: lenderName, relationship: relationship)
        family = await services.family.state()
        let approved = try await services.family.awaitApproval(loanID: request.id)
        family = await services.family.state()
        if approved.status == .approved {
            try await addTransaction(Transaction(date: .now, description: "Transfer from \(approved.lenderName) - \(approved.purpose.lowercased()) loan",
                                                 amount: approved.amount, category: .transfer))
        }
    }

    func payInstalment(_ loan: FamilyLoan) async throws {
        let payment = try await services.family.payInstalment(loanID: loan.id)
        family = await services.family.state()
        try await addTransaction(Transaction(date: .now, description: "Transfer to \(loan.lenderName) - loan repayment",
                                             amount: -payment.amount, category: .transfer))
    }

    func payBill(_ bill: SharedBill) async throws {
        let payment = try await services.family.payBill(billID: bill.id)
        family = await services.family.state()
        try await addTransaction(Transaction(date: .now, description: "Transfer to \(bill.partnerName) - \(bill.name.lowercased())",
                                             amount: -payment.amount, category: .transfer))
    }

    // MARK: Piggy Bank

    var piggy: PiggyBank? { savingsAccount?.piggy }

    /// 1 normally. During hardship (income down more than 30% month on month),
    /// the ratio of this month's income to last month's, used to ease goals and limits.
    var hardshipScale: Double { ReadinessRules.hardshipScale(transactions) }

    func setPiggyGoal(name: String, amount: Double, targetDate: Date?) async {
        var piggy = self.piggy ?? PiggyBank(goalName: name, goalAmount: amount)
        piggy.goalName = name.trimmingCharacters(in: .whitespaces)
        piggy.goalAmount = max(1, amount)
        piggy.targetDate = targetDate
        if piggy.saved < piggy.goalAmount { piggy.goalReachedAt = nil }
        savingsAccount = await services.savings.updatePiggy(piggy)
    }

    /// Moves money (from £1) into the Piggy Bank with `SavingsServicing.topUp`.
    /// Reaching the goal pays the example matched-savings bonus once, if rewards are on.
    @discardableResult
    func addToPiggy(_ amount: Double, isPromise: Bool = false, rewardsOn: Bool = true) async throws -> Double {
        guard amount >= 1, var piggy else { throw ServiceError.invalidAmount }
        _ = try await services.savings.topUp(amount)
        piggy.saved += amount
        piggy.deposits.append(PiggyDeposit(date: .now, amount: amount, isPromise: isPromise))
        var bonus = 0.0
        if piggy.goalReachedAt == nil, piggy.saved >= piggy.goalAmount {
            piggy.goalReachedAt = .now
            if rewardsOn {
                bonus = PiggyRules.matchBonus(saved: piggy.saved)
                if bonus > 0 {
                    _ = try await services.savings.depositPayout(bonus, reference: "MATCHED BONUS (EXAMPLE)")
                    piggy.bonusPaid = bonus
                }
            }
        }
        savingsAccount = await services.savings.updatePiggy(piggy)
        try await addTransaction(Transaction(date: .now, description: isPromise ? "Transfer to Piggy Bank - promise to myself" : "Transfer to Piggy Bank",
                                             amount: -amount, category: .transfer))
        await refreshSavings()
        return bonus
    }

    func setPromise(amount: Double?, weekday: Int) async {
        guard var piggy else { return }
        if let amount, amount >= 1 {
            piggy.promise = PromiseToMyself(amount: amount, weekday: weekday, startDate: .now, payments: piggy.promise?.payments ?? [])
        } else {
            piggy.promise = nil
        }
        savingsAccount = await services.savings.updatePiggy(piggy)
        await refreshReadiness()
    }

    /// Makes this week's promised transfer. On time counts towards Reliability like a bill.
    func keepPromise(rewardsOn: Bool = true) async throws {
        guard let promise = piggy?.promise, let due = promise.nextDue() else { throw ServiceError.nothingDue }
        try await addToPiggy(promise.amount, isPromise: true, rewardsOn: rewardsOn)
        guard var piggy else { return }
        piggy.promise?.payments.append(FamilyPayment(due: due.due, amount: promise.amount, paid: .now))
        savingsAccount = await services.savings.updatePiggy(piggy)
        await refreshReadiness()
    }

    // MARK: Nova Explorer

    /// Loads the save game and the park, then turns new real savings milestones into XP.
    /// Returns the rewards given (for toasts).
    @discardableResult
    func loadExplorer() async -> [ExplorerReward] {
        explorer = await services.explorer.progress()
        park = await services.park.status()
        return await syncSavingsToExplorer()
    }

    /// Real-to-game sync: Piggy Bank % of your own goal and your saving streak (never £ amounts).
    func syncSavingsToExplorer() async -> [ExplorerReward] {
        let streak = PiggyRules.savingStreakMonths(ReadinessRules.savingDeposits(transactions, piggy: piggy), now: .now)
        let rewards = ExplorerEconomy.savingsRewards(piggy: piggy, savingStreakMonths: streak, hardshipScale: hardshipScale,
                                                     claimed: explorer.claimedRewards)
        guard !rewards.isEmpty else { return [] }
        var progress = explorer
        var given: [ExplorerReward] = []
        for reward in rewards {
            let xp = ExplorerEconomy.grant(reward.xp, coins: reward.coins, to: &progress)
            progress.claimedRewards.append(reward.key)
            given.append(ExplorerReward(key: reward.key, title: reward.title, xp: xp, coins: reward.coins))
            if reward.key.hasSuffix(":100"), !progress.badges.contains("saver") { progress.badges.append("saver") }
        }
        await saveExplorer(progress)
        return given
    }

    func saveExplorer(_ progress: ExplorerProgress) async {
        explorer = progress
        await services.explorer.save(progress)
    }

    /// Records a finished Explorer quest: capped XP and coins, a park point and any badge.
    func completeExplorerQuest(_ questID: String, isMoneyQuest: Bool, badge: String? = nil) async -> (xp: Int, coins: Int) {
        var progress = explorer
        let reward = ExplorerEconomy.questReward(questID: questID, isMoneyQuest: isMoneyQuest, progress: progress)
        let coinsBefore = progress.coins
        let xp = ExplorerEconomy.grant(reward.xp, coins: reward.coins, to: &progress)
        if !progress.completedQuests.contains(questID) {
            progress.completedQuests.append(questID)
            progress.parkTokens += 1
        }
        if let badge, !progress.badges.contains(badge) { progress.badges.append(badge) }
        await saveExplorer(progress)
        return (xp, progress.coins - coinsBefore)
    }

    /// Gives banked park points (up to today's cap) to the shared Community Park.
    func contributeToPark() async throws -> Int {
        var progress = explorer
        let room = max(0, ExplorerEconomy.dailyParkPoints - progress.parkPointsToday())
        let points = min(progress.parkTokens, room)
        guard points > 0 else { throw ServiceError.nothingDue }
        park = try await services.park.contribute(points: points)
        progress.parkTokens -= points
        progress.parkPointsByDay[MoneyQuestRules.dayKey(.now), default: 0] += points
        progress.parkContributed += points
        await saveExplorer(progress)
        return points
    }

    /// Marks a quest as done without extra XP (for example a Money Quest chapter NPC).
    func markExplorerQuest(_ questID: String) async {
        guard !explorer.completedQuests.contains(questID) else { return }
        var progress = explorer
        progress.completedQuests.append(questID)
        await saveExplorer(progress)
    }

    func refreshPark() async {
        park = await services.park.status()
    }

    // MARK: Money Quest

    /// Records a finished level. Points are capped per day; Wisdom counts up to 3 new levels a day.
    func completeQuestLevel(_ level: QuestLevel, in chapter: QuestChapter, correctAnswers: Int) async -> LevelReward {
        let reward = await services.game.completeLevel(level.id, in: chapter, correctAnswers: correctAnswers)
        game = await services.game.progress()
        if reward.countsForWisdom { await recordWisdom(.moneyQuestLevel) }
        return reward
    }

    // MARK: Demo

    /// Profile > Demo switch: Adult, Teen A or Teen B, with matching demo data.
    func switchDemoProfile(to profile: DemoProfile) async {
        guard profile != demoProfile || profile.stage != stage else { return }
        await resetDemo(to: profile)
        await reloadData()
    }

    /// Sets the stage override and reloads every demo data set for the profile.
    private func resetDemo(to profile: DemoProfile) async {
        let newStage = profile.stage
        demoStageOverride = newStage == user?.stage ? nil : newStage
        if let demoStageOverride {
            UserDefaults.standard.set(demoStageOverride.rawValue, forKey: Self.demoStageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.demoStageKey)
        }
        await resetDemoServices(for: profile)
    }

    private func resetDemoServices(for profile: DemoProfile) async {
        demoProfile = profile
        UserDefaults.standard.set(profile.rawValue, forKey: Self.demoProfileKey)
        savingsAccount = await services.savings.resetDemo(profile: profile)
        _ = try? await services.transactions.loadDemoData(profile: profile)
        await services.readiness.resetDemo(profile: profile)
        await services.arenas.resetDemo(profile: profile)
        await services.family.resetDemo(profile: profile)
        await services.game.resetDemo(profile: profile)
        await services.explorer.resetDemo(profile: profile)
    }

    // MARK: Plan

    func setPlan(_ newPlan: Plan) { plan = newPlan }

    /// Returns true when the feature can be used; otherwise shows the locked-feature sheet.
    func require(_ feature: ProFeature) -> Bool {
        if isPro { return true }
        lockedFeature = feature
        return false
    }
}
