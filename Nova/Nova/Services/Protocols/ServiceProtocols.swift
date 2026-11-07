import Foundation

// The service layer. Views and view models only talk to these protocols.
// To plug in the real backend, write a type that conforms to each protocol
// and pass it to `ServiceContainer`. No UI code needs to change.

enum ServiceError: LocalizedError, Equatable {
    case invalidCredentials
    case emailInUse
    case notSignedIn
    case invalidJoinCode
    case alreadyMember
    case insufficientFunds
    case unreadableFile
    case paymentDeclined
    case invalidAmount
    case nothingDue
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "That email and password don't match. Try again."
        case .emailInUse: "An account with that email already exists."
        case .notSignedIn: "Please sign in first."
        case .invalidJoinCode: "We couldn't find an arena with that code."
        case .alreadyMember: "You're already in this arena."
        case .insufficientFunds: "There isn't enough money in your savings account for this stake."
        case .unreadableFile: "We couldn't read that file. Use a JSON, CSV or PDF statement."
        case .paymentDeclined: "Your card was declined. Check the details and try again."
        case .invalidAmount: "Enter an amount of £1 or more."
        case .nothingDue: "There's nothing to pay right now."
        case .network(let message): message
        }
    }
}

/// Sign in, sign up and the current session.
protocol AuthServicing: AnyObject, Sendable {
    var currentUser: UserProfile? { get }
    func signIn(email: String, password: String) async throws -> UserProfile
    func signUp(name: String, email: String, password: String) async throws -> UserProfile
    func signOut() async
    func updateBank(_ bank: Bank) async
    func updateDateOfBirth(_ date: Date?) async
}

/// The user's transactions. Replaces the original backend upload endpoints
/// (`/parse-pdf`) and the local transaction store.
protocol TransactionServicing: AnyObject, Sendable {
    func fetchTransactions() async throws -> [Transaction]
    /// Replaces the stored transactions with demo data for a life stage (manual entries are kept).
    func loadDemoData(stage: LifeStage) async throws -> [Transaction]
    func importStatement(_ data: Data, type: ImportFileType) async throws -> [Transaction]
    func add(_ transaction: Transaction) async throws
    func delete(id: UUID) async throws
    func clearAll() async throws
}

extension TransactionServicing {
    func loadDemoData() async throws -> [Transaction] { try await loadDemoData(stage: .adult) }
}

/// Predictions and insights. Maps to the original `/week-ahead`, `/income-runway`,
/// `/budget-tips` and `/financial-summary` endpoints.
protocol InsightsServicing: AnyObject, Sendable {
    func weather() async throws -> Weather
    func weekAhead(from transactions: [Transaction]) async throws -> [DayPrediction]
    func briefing(from transactions: [Transaction], name: String) async throws -> MorningBriefing
    func alerts(from transactions: [Transaction]) async throws -> [SpendingAlert]
    func weeklyRecap(from transactions: [Transaction]) async throws -> WeeklyRecap
    func runway(summary: FinancialSummary) async throws -> RunwayResult
    func budgetTips(summary: FinancialSummary) async throws -> [String]
    func whatIf(_ question: String, summary: FinancialSummary, transactions: [Transaction]) async throws -> WhatIfResult
}

/// The "Ask Nova" assistant. Replaces the original Groq chat service.
protocol ChatServicing: AnyObject, Sendable {
    /// `stage` tells the assistant whether it's talking to a teen (no credit products, short answers).
    func reply(to message: String, history: [ChatMessage], summary: FinancialSummary, stage: LifeStage) async throws -> String
}

/// Speech in and out. Replaces ElevenLabs (text to speech) and Whisper (speech to text).
protocol VoiceServicing: AnyObject, Sendable {
    var isSpeaking: Bool { get }
    func speak(_ text: String)
    func stopSpeaking()
    /// Records the user's question and returns it as text.
    func transcribe() async throws -> String
    /// Ends a recording started by `transcribe()` early (the user tapped the mic again).
    func stopListening()
}

extension VoiceServicing {
    func stopListening() {}
}

/// Arenas: create, join, sync spending and settle. Replaces Supabase + Solana.
protocol ArenaServicing: AnyObject, Sendable {
    func myArenas() async throws -> [Arena]
    func create(name: String, mode: ArenaMode, target: Double, stake: Double, vice: SpendingCategory?, endDate: Date) async throws -> Arena
    func join(code: String) async throws -> Arena
    func preview(code: String) async throws -> Arena
    func sync(arenaID: UUID, transactions: [Transaction]) async throws -> Arena
    func settle(arenaID: UUID) async throws -> ArenaSettlement
    /// Demo only: arenas that fit the life stage. Shared backend arenas are left alone.
    func resetDemo(stage: LifeStage) async
}

extension ArenaServicing {
    func resetDemo(stage: LifeStage) async {}
}

/// The NatWest savings account that holds arena stakes and receives prize pots.
protocol SavingsServicing: AnyObject, Sendable {
    func account() async throws -> SavingsAccount
    func withdrawStake(_ amount: Double, reference: String) async throws -> SavingsAccount
    func depositPayout(_ amount: Double, reference: String) async throws -> SavingsAccount
    func topUp(_ amount: Double) async throws -> SavingsAccount
    /// Demo only: resets the account to a balance that fits the life stage.
    func resetDemo(stage: LifeStage) async -> SavingsAccount
}

/// Free / Pro plan. Replaces Stripe.
protocol SubscriptionServicing: AnyObject, Sendable {
    var plan: Plan { get }
    var trialEndsAt: Date? { get }
    func startProTrial(cardNumber: String, expiry: String, cvc: String) async throws -> Plan
    func cancel() async -> Plan
}

/// The Readiness Score, streak and Wisdom progress. On-device in both containers.
protocol ReadinessServicing: AnyObject, Sendable {
    func progress() async -> ReadinessProgress
    /// Scores the user, saves today's score for the 30-day chart and returns the result.
    func evaluate(_ input: ReadinessInput) async -> ReadinessSnapshot
    func record(_ event: WisdomEvent) async -> ReadinessProgress
    func setWeeklyLimit(_ limit: Double?) async -> ReadinessProgress
    /// Today's quest, created from today's predictions the first time it's asked for.
    func todaysQuest(predictions: [PredictionItem]) async -> DailyQuest?
    /// Demo only: marks today's quest as completed now instead of at the end of the day.
    func completeTodaysQuest() async -> ReadinessProgress
    /// Graduation checklist items set by hand (voting) or by opening the report.
    func setVotingChecked(_ done: Bool) async -> ReadinessProgress
    func markReportPreviewed() async -> ReadinessProgress
    /// Demo only: starting progress that fits the life stage.
    func resetDemo(stage: LifeStage) async
}

/// Family loans and shared bills (Teen mode). On-device in both containers.
protocol FamilyServicing: AnyObject, Sendable {
    func state() async -> FamilyState
    func requestLoan(purpose: String, amount: Double, instalments: Int, lenderName: String, relationship: String) async throws -> FamilyLoan
    /// Demo: the trusted adult answers after a short delay.
    func awaitApproval(loanID: UUID) async throws -> FamilyLoan
    func payInstalment(loanID: UUID) async throws -> FamilyPayment
    func addBill(name: String, amount: Double, dayOfMonth: Int, partnerName: String, relationship: String) async throws -> SharedBill
    func payBill(billID: UUID) async throws -> FamilyPayment
    func resetDemo(stage: LifeStage) async
}
