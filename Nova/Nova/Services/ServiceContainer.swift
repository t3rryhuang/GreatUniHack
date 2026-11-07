import SwiftUI

/// Holds one implementation of every service. The app uses `.mock` today.
/// To connect the real backend, build a container with real implementations
/// in `NovaApp` and nothing else changes.
struct ServiceContainer {
    let auth: AuthServicing
    let transactions: TransactionServicing
    let insights: InsightsServicing
    let chat: ChatServicing
    let voice: VoiceServicing
    let arenas: ArenaServicing
    let savings: SavingsServicing
    let subscription: SubscriptionServicing

    static func mock() -> ServiceContainer {
        let auth = MockAuthService()
        let savings = MockSavingsService()
        return ServiceContainer(
            auth: auth,
            transactions: MockTransactionService(),
            insights: MockInsightsService(),
            chat: MockChatService(),
            voice: SystemVoiceService(),
            arenas: MockArenaService(savings: savings, auth: auth),
            savings: savings,
            subscription: MockSubscriptionService()
        )
    }
}
