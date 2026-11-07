import Foundation

/// Arenas shared between real users through the backend (`/arenas`).
///
/// The server stores who is in each arena, their progress and the result.
/// Money still moves in the user's savings account on this device: the stake is
/// withdrawn when you create or join, and the prize pot is paid in when you win
/// (even if another member was the one who pressed "Settle").
final class RemoteArenaService: ArenaServicing {
    private let client: BackendClient
    private let savings: SavingsServicing
    private let auth: AuthServicing
    private let paidStoreName = "arena-payouts.json"
    private var paidReferences: Set<String>

    init(client: BackendClient, savings: SavingsServicing, auth: AuthServicing) {
        self.client = client
        self.savings = savings
        self.auth = auth
        self.paidReferences = LocalStore.load(Set<String>.self, from: paidStoreName) ?? []
    }

    private var headers: [String: String] {
        get throws {
            guard let user = auth.currentUser else { throw ServiceError.notSignedIn }
            // Email is the stable identity across devices (the mock sign-in makes a new id each time).
            return ["X-User-Id": user.email, "X-User-Name": user.name]
        }
    }

    // MARK: ArenaServicing

    func myArenas() async throws -> [Arena] {
        let arenas: [Arena] = try await client.send("GET", "arenas", headers: try headers)
        for arena in arenas where arena.status == .completed {
            try? await collectPayoutIfWon(arena)
        }
        return arenas
    }

    func create(name: String, mode: ArenaMode, target: Double, stake: Double, vice: SpendingCategory?, endDate: Date) async throws -> Arena {
        let headers = try headers
        // Check funds before creating so we never leave an arena without a stake.
        let account = try await savings.account()
        guard account.balance >= stake else { throw ServiceError.insufficientFunds }
        let body = CreateBody(name: name, mode: mode.rawValue, targetAmount: target, stakeAmount: stake,
                              viceCategory: vice?.rawValue, endDate: endDate)
        let arena: Arena = try await client.send("POST", "arenas", body: body, headers: headers)
        _ = try await savings.withdrawStake(stake, reference: "ARENA \(arena.joinCode)")
        return arena
    }

    func preview(code: String) async throws -> Arena {
        do {
            return try await client.send("GET", "arenas/code/\(code)", headers: try headers)
        } catch let error as BackendError {
            throw map(error)
        }
    }

    func join(code: String) async throws -> Arena {
        let headers = try headers
        let preview = try await preview(code: code)
        let account = try await savings.account()
        guard account.balance >= preview.stakeAmount else { throw ServiceError.insufficientFunds }
        do {
            let arena: Arena = try await client.send("POST", "arenas/join", body: ["code": code], headers: headers)
            _ = try await savings.withdrawStake(arena.stakeAmount, reference: "ARENA \(code)")
            return arena
        } catch let error as BackendError {
            throw map(error)
        }
    }

    func sync(arenaID: UUID, transactions: [Transaction]) async throws -> Arena {
        let headers = try headers
        let current: Arena = try await client.send("GET", "arenas/\(arenaID.uuidString)", headers: headers)
        let progress = Self.progress(for: current, transactions: transactions)
        let arena: Arena = try await client.send("POST", "arenas/\(arenaID.uuidString)/sync", body: progress, headers: headers)
        if arena.status == .completed { try? await collectPayoutIfWon(arena) }
        return arena
    }

    func settle(arenaID: UUID) async throws -> ArenaSettlement {
        let result: SettleResponse
        do {
            result = try await client.send("POST", "arenas/\(arenaID.uuidString)/settle", headers: try headers)
        } catch let error as BackendError {
            throw ServiceError.network(error.message)
        }
        if result.winner?.isCurrentUser == true { try await credit(result.payout, reference: result.reference) }
        return ArenaSettlement(arenaID: result.arena.id, winner: result.winner, standings: result.standings,
                               payout: result.payout, reference: result.reference, settledAt: result.settledAt)
    }

    // MARK: Helpers

    /// The caller's own progress for this arena, computed from their transactions (same rules as the mock).
    static func progress(for arena: Arena, transactions: [Transaction]) -> ProgressBody {
        let inPeriod = transactions.filter { $0.date >= arena.startDate && $0.date <= min(arena.endDate, .now) }
        switch arena.mode {
        case .budgetGuardian:
            let spend = inPeriod.filter { $0.isExpense && ![.rent, .transfer, .utilities].contains($0.category) }
                .reduce(0) { $0 + $1.spend }
            return ProgressBody(currentSpend: spend, currentSavings: 0)
        case .viceStreak:
            let vice = arena.viceCategory ?? .coffee
            let spend = inPeriod.filter { $0.category == vice && $0.isExpense }.reduce(0) { $0 + $1.spend }
            return ProgressBody(currentSpend: spend, currentSavings: 0)
        case .savingsSprint:
            let saved = inPeriod.filter { $0.category == .transfer && $0.isExpense }.reduce(0) { $0 + $1.spend }
            return ProgressBody(currentSpend: 0, currentSavings: saved)
        }
    }

    /// If another member settled an arena we won, pay the pot into our savings account once.
    private func collectPayoutIfWon(_ arena: Arena) async throws {
        guard let winnerID = arena.winnerID,
              arena.members.first(where: { $0.id == winnerID })?.isCurrentUser == true else { return }
        let result: SettleResponse = try await client.send("POST", "arenas/\(arena.id.uuidString)/settle", headers: try headers)
        try await credit(result.payout, reference: result.reference)
    }

    private func credit(_ amount: Double, reference: String) async throws {
        guard !paidReferences.contains(reference) else { return }
        _ = try await savings.depositPayout(amount, reference: reference)
        paidReferences.insert(reference)
        LocalStore.save(paidReferences, to: paidStoreName)
    }

    private func map(_ error: BackendError) -> Error {
        switch error.status {
        case 404: ServiceError.invalidJoinCode
        case 409: ServiceError.alreadyMember
        default: ServiceError.network(error.message)
        }
    }

    struct CreateBody: Encodable {
        let name: String
        let mode: String
        let targetAmount: Double
        let stakeAmount: Double
        let viceCategory: String?
        let endDate: Date
    }

    struct ProgressBody: Encodable {
        let currentSpend: Double
        let currentSavings: Double
    }

    struct SettleResponse: Decodable {
        let arena: Arena
        let winner: ArenaMember?
        let standings: [ArenaMember]
        let payout: Double
        let reference: String
        let settledAt: Date
    }
}
