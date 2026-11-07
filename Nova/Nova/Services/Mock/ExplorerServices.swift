import Foundation

/// Nova Explorer save game, on this device (`explorer.json`).
final class LocalExplorerService: ExplorerServicing {
    private let storeName = "explorer.json"
    private var state: ExplorerProgress

    init() {
        state = LocalStore.load(ExplorerProgress.self, from: storeName) ?? ExplorerProgress()
        state.equippedCosmetic = CosmeticCatalogue.validate(state.equippedCosmetic)
    }

    func progress() async -> ExplorerProgress { state }

    func save(_ progress: ExplorerProgress) async {
        state = progress
        state.equippedCosmetic = CosmeticCatalogue.validate(progress.equippedCosmetic)
        LocalStore.save(state, to: storeName)
    }

    func resetDemo(profile: DemoProfile) async {
        // Every demo starts at the first spawn, so Remi's styling scene can be shown.
        state = ExplorerProgress()
        LocalStore.save(state, to: storeName)
    }
}

/// Remi offline: the on-device keyword rules.
final class MockStylistService: StylistServicing {
    private var turn = 0

    func reply(to message: String, current: AvatarLook, history: [StylistTurn]) async -> StylistReply {
        await simulateLatency(500)
        turn += 1
        return StylistRules.reply(to: message, current: current, seed: turn)
    }
}

/// Community Park offline: a local total that starts part-built, so the demo shows benches and trees.
final class MockCommunityParkService: CommunityParkServicing {
    private let storeName = "park.json"
    private var state: ParkStatus

    init() {
        state = LocalStore.load(ParkStatus.self, from: storeName) ?? ParkStatus(total: 2_840, contributors: 412)
    }

    func status() async -> ParkStatus {
        await simulateLatency(200)
        return state
    }

    func contribute(points: Int) async throws -> ParkStatus {
        guard (1...ExplorerEconomy.dailyParkPoints).contains(points) else { throw ServiceError.invalidAmount }
        await simulateLatency(300)
        state.total += points
        state.contributors += 1
        LocalStore.save(state, to: storeName)
        return state
    }
}
