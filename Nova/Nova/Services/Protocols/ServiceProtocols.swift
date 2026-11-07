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
}

/// The user's transactions. Replaces the original backend upload endpoints
/// (`/parse-pdf`) and the local transaction store.
protocol TransactionServicing: AnyObject, Sendable {
    func fetchTransactions() async throws -> [Transaction]
    func loadDemoData() async throws -> [Transaction]
    func importStatement(_ data: Data, type: ImportFileType) async throws -> [Transaction]
    func add(_ transaction: Transaction) async throws
    func delete(id: UUID) async throws
    func clearAll() async throws
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
    func reply(to message: String, history: [ChatMessage], summary: FinancialSummary) async throws -> String
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
}

/// The NatWest savings account that holds arena stakes and receives prize pots.
protocol SavingsServicing: AnyObject, Sendable {
    func account() async throws -> SavingsAccount
    func withdrawStake(_ amount: Double, reference: String) async throws -> SavingsAccount
    func depositPayout(_ amount: Double, reference: String) async throws -> SavingsAccount
    func topUp(_ amount: Double) async throws -> SavingsAccount
}

/// Free / Pro plan. Replaces Stripe.
protocol SubscriptionServicing: AnyObject, Sendable {
    var plan: Plan { get }
    var trialEndsAt: Date? { get }
    func startProTrial(cardNumber: String, expiry: String, cvc: String) async throws -> Plan
    func cancel() async -> Plan
}
