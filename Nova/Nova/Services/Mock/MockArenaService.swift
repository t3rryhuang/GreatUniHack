import Foundation

/// Mock arenas. Stakes are held from, and prize pots paid into, the user's
/// NatWest savings account through `SavingsServicing`.
final class MockArenaService: ArenaServicing {
    /// Codes that can be joined in demo mode.
    static let demoJoinCodes = ["246810", "135790", "112233"]

    /// Demo codes that fit a life stage (teens only see arenas without money).
    static func demoJoinCodes(for stage: LifeStage) -> [String] {
        stage == .teen ? ["112233"] : demoJoinCodes
    }

    private let storeName = "arenas.json"
    private let savings: SavingsServicing
    private let auth: AuthServicing
    private var arenas: [Arena]

    init(savings: SavingsServicing, auth: AuthServicing) {
        self.savings = savings
        self.auth = auth
        self.arenas = LocalStore.load([Arena].self, from: storeName) ?? []
    }

    private var me: UserProfile {
        get throws {
            guard let user = auth.currentUser else { throw ServiceError.notSignedIn }
            return user
        }
    }

    func myArenas() async throws -> [Arena] {
        await simulateLatency(400)
        if arenas.isEmpty {
            let user = try me
            arenas = MockDataFactory.demoArenas(currentUser: user, stage: user.stage)
            persist()
        }
        return arenas.sorted { ($0.status == .completed ? 1 : 0, $0.endDate) < ($1.status == .completed ? 1 : 0, $1.endDate) }
    }

    func create(name: String, mode: ArenaMode, target: Double, stake: Double, vice: SpendingCategory?, endDate: Date, teen: Bool) async throws -> Arena {
        let user = try me
        let code = String(format: "%06d", Int.random(in: 100_000...999_999))
        if stake > 0 { _ = try await savings.withdrawStake(stake, reference: "ARENA \(code)") }
        let arena = Arena(
            name: name,
            mode: mode,
            targetAmount: target,
            stakeAmount: stake,
            viceCategory: mode == .viceStreak ? vice : nil,
            startDate: .now,
            endDate: endDate,
            joinCode: code,
            status: .pending,
            members: [ArenaMember(name: user.name, isCurrentUser: true, lastSyncedAt: .now)],
            teen: teen ? true : nil
        )
        arenas.insert(arena, at: 0)
        persist()
        return arena
    }

    func preview(code: String) async throws -> Arena {
        await simulateLatency(500)
        if arenas.contains(where: { $0.joinCode == code }) { throw ServiceError.alreadyMember }
        guard let arena = Self.publicArena(code: code) else { throw ServiceError.invalidJoinCode }
        return arena
    }

    func join(code: String) async throws -> Arena {
        let user = try me
        var arena = try await preview(code: code)
        if arena.stakeAmount > 0 { _ = try await savings.withdrawStake(arena.stakeAmount, reference: "ARENA \(code)") }
        arena.members.append(ArenaMember(name: user.name, isCurrentUser: true, lastSyncedAt: .now))
        arena.status = .active
        arenas.insert(arena, at: 0)
        persist()
        return arena
    }

    func sync(arenaID: UUID, transactions: [Transaction]) async throws -> Arena {
        await simulateLatency(700)
        guard let index = arenas.firstIndex(where: { $0.id == arenaID }) else { throw ServiceError.invalidJoinCode }
        var arena = arenas[index]
        let mine = ArenaRules.progress(for: arena, transactions: transactions)

        for i in arena.members.indices {
            if arena.members[i].isCurrentUser {
                switch arena.mode {
                case .budgetGuardian:
                    arena.members[i].currentSpend = max(arena.members[i].currentSpend, mine.spend)
                    if let baseline = mine.baseline { arena.members[i].baselineSpend = baseline }
                case .viceStreak:
                    arena.members[i].currentSpend = mine.spend
                case .savingsSprint:
                    arena.members[i].currentSavings = max(arena.members[i].currentSavings, mine.savings)
                    if let target = mine.personalTarget { arena.members[i].personalTarget = target }
                case .mostImproved:
                    arena.members[i].currentSpend = mine.spend
                    if let baseline = mine.baseline { arena.members[i].baselineSpend = baseline }
                }
            } else if arena.status != .completed {
                // Friends' spending drifts a little each sync, so the demo feels live.
                arena.members[i].currentSpend += arena.mode == .viceStreak ? 0 : Double.random(in: 0...(arena.mode == .mostImproved ? 6 : 12))
                arena.members[i].currentSavings += arena.mode == .savingsSprint ? Double.random(in: 0...15) : 0
            }

            let member = arena.members[i]
            let over = ArenaRules.hasSpendingLimit(arena.mode) && member.currentSpend > ArenaRules.limit(for: member, in: arena)
            if over && member.exceededAt == nil {
                arena.members[i].exceededAt = .now
                if arena.mode == .viceStreak { arena.members[i].isEliminated = true }
            }
            let reached = arena.isTeenArena ? (member.ownTargetProgress ?? 0) >= 1 : member.currentSavings >= arena.targetAmount
            if arena.mode == .savingsSprint && reached && member.targetReachedAt == nil {
                arena.members[i].targetReachedAt = .now
            }
            arena.members[i].lastSyncedAt = .now
        }
        if arena.status == .pending && arena.members.count >= 2 { arena.status = .active }
        arenas[index] = arena
        persist()
        return arena
    }

    func settle(arenaID: UUID) async throws -> ArenaSettlement {
        await simulateLatency(1_200)
        guard let index = arenas.firstIndex(where: { $0.id == arenaID }) else { throw ServiceError.invalidJoinCode }
        var arena = arenas[index]
        let standings = ArenaRules.standings(for: arena)
        let winner = standings.first
        let reference = "NW-ARENA-\(arena.joinCode)-\(Int(Date.now.timeIntervalSince1970) % 100_000)"
        if winner?.isCurrentUser == true, arena.prizePot > 0 {
            _ = try await savings.depositPayout(arena.prizePot, reference: reference)
        }
        arena.status = .completed
        arena.winnerID = winner?.id
        arenas[index] = arena
        persist()
        return ArenaSettlement(arenaID: arena.id, winner: winner, standings: standings, payout: arena.prizePot, reference: reference, settledAt: .now)
    }

    func resetDemo(stage: LifeStage) async {
        guard let user = auth.currentUser else { return }
        arenas = MockDataFactory.demoArenas(currentUser: user, stage: stage)
        persist()
    }

    private func persist() { LocalStore.save(arenas, to: storeName) }

    private static func publicArena(code: String) -> Arena? {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -2, to: .now) ?? .now
        switch code {
        case "246810":
            return Arena(
                name: "Office Lunch Challenge", mode: .budgetGuardian, targetAmount: 150, stakeAmount: 5,
                startDate: start, endDate: calendar.date(byAdding: .day, value: 12, to: .now) ?? .now,
                joinCode: code, status: .active,
                members: [ArenaMember(name: "Tom Okafor", currentSpend: 22), ArenaMember(name: "Ellie Clarke", currentSpend: 31)]
            )
        case "135790":
            return Arena(
                name: "Dry January Again", mode: .viceStreak, targetAmount: 0, stakeAmount: 10, viceCategory: .drinks,
                startDate: start, endDate: calendar.date(byAdding: .day, value: 20, to: .now) ?? .now,
                joinCode: code, status: .active,
                members: [ArenaMember(name: "Sam Hughes"), ArenaMember(name: "Aisha Rahman"), ArenaMember(name: "Jack Murphy")]
            )
        case "112233":
            return Arena(
                name: "Weekend Spend-Off", mode: .mostImproved, targetAmount: 0, stakeAmount: 0,
                startDate: start, endDate: calendar.date(byAdding: .day, value: 12, to: .now) ?? .now,
                joinCode: code, status: .active,
                members: [ArenaMember(name: "Maya Ahmed", currentSpend: 18, baselineSpend: 30),
                          ArenaMember(name: "Leo Byrne", currentSpend: 22, baselineSpend: 26)],
                teen: true
            )
        default:
            return nil
        }
    }
}
