import SwiftUI

/// Holds one implementation of every service. `.live()` uses the Vercel backend
/// for arenas, AI insights, chat and voice; `.mock()` is fully on-device.
struct ServiceContainer {
    let auth: AuthServicing
    let transactions: TransactionServicing
    let insights: InsightsServicing
    let chat: ChatServicing
    let voice: VoiceServicing
    let arenas: ArenaServicing
    let savings: SavingsServicing
    let subscription: SubscriptionServicing
    let readiness: ReadinessServicing
    let family: FamilyServicing
    let game: GameServicing

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
            subscription: MockSubscriptionService(),
            readiness: LocalReadinessService(),
            family: LocalFamilyService(),
            game: LocalGameService()
        )
    }

    /// Arenas, insights, chat and read-aloud go to the backend. Sign-in, transactions,
    /// the savings account, the Pro plan and the Readiness Score stay on-device.
    static func live(baseURL: URL) -> ServiceContainer {
        let client = BackendClient(baseURL: baseURL)
        let auth = MockAuthService()
        let savings = MockSavingsService()
        return ServiceContainer(
            auth: auth,
            transactions: MockTransactionService(),
            insights: RemoteInsightsService(client: client),
            chat: RemoteChatService(client: client),
            voice: ElevenLabsVoiceService(client: client),
            arenas: RemoteArenaService(client: client, savings: savings, auth: auth),
            savings: savings,
            subscription: MockSubscriptionService(),
            readiness: LocalReadinessService(),
            family: LocalFamilyService(),
            game: LocalGameService()
        )
    }
}
