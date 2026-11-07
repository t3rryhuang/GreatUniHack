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
    var errorMessage: String?

    /// Presentation state for app-wide sheets.
    var showUpgrade = false
    var showChat = false
    var showBriefing = false
    var showAddTransaction = false
    var lockedFeature: ProFeature?

    var isPro: Bool { plan == .pro }
    var hasData: Bool { !transactions.isEmpty }

    init(services: ServiceContainer) {
        self.services = services
    }

    func start() async {
        plan = services.subscription.plan
        #if DEBUG
        // Launch with `-NovaDemo` to skip sign-in and onboarding (handy for demos and screenshots).
        if ProcessInfo.processInfo.arguments.contains("-NovaDemo"), services.auth.currentUser == nil {
            if (try? await services.auth.signIn(email: "alex.taylor@example.com", password: "demo1234")) != nil {
                _ = try? await services.transactions.loadDemoData()
                await services.auth.updateBank(.natwest)
            }
        }
        #endif
        guard let current = services.auth.currentUser else {
            phase = .signedOut
            return
        }
        user = current
        await reloadData()
        phase = hasData ? .ready : .onboarding
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
    }

    func apply(_ newTransactions: [Transaction]) {
        transactions = newTransactions
        summary = FinancialSummary.make(from: newTransactions, savingsBalance: savingsAccount?.balance ?? 0)
        dataVersion += 1
    }

    func loadDemoData() async throws {
        apply(try await services.transactions.loadDemoData())
    }

    func importStatement(_ data: Data, type: ImportFileType) async throws {
        apply(try await services.transactions.importStatement(data, type: type))
    }

    func addTransaction(_ transaction: Transaction) async throws {
        try await services.transactions.add(transaction)
        apply(try await services.transactions.fetchTransactions())
    }

    func deleteTransaction(_ id: UUID) async {
        try? await services.transactions.delete(id: id)
        apply(transactions.filter { $0.id != id })
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
        }
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
