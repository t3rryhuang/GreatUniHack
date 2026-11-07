import Foundation
import Observation

@Observable
final class ArenaListViewModel {
    private(set) var arenas: [Arena] = []
    private(set) var isLoading = false

    var active: [Arena] { arenas.filter { $0.status != .completed } }
    var completed: [Arena] { arenas.filter { $0.status == .completed } }

    func load(model: AppModel) async {
        isLoading = arenas.isEmpty
        defer { isLoading = false }
        do {
            arenas = try await model.services.arenas.myArenas()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    func upsert(_ arena: Arena) {
        if let index = arenas.firstIndex(where: { $0.id == arena.id }) { arenas[index] = arena } else { arenas.insert(arena, at: 0) }
    }
}

@Observable
final class ArenaDetailViewModel {
    private(set) var arena: Arena
    private(set) var isSyncing = false
    private(set) var isSettling = false
    var settlement: ArenaSettlement?

    init(arena: Arena) { self.arena = arena }

    var standings: [ArenaMember] { ArenaRules.standings(for: arena) }
    var me: ArenaMember? { arena.members.first(where: \.isCurrentUser) }

    func sync(model: AppModel) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            arena = try await model.services.arenas.sync(arenaID: arena.id, transactions: model.transactions)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    func settle(model: AppModel) async {
        isSettling = true
        defer { isSettling = false }
        do {
            let result = try await model.services.arenas.settle(arenaID: arena.id)
            arena.status = .completed
            arena.winnerID = result.winner?.id
            settlement = result
            await model.refreshSavings()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

@Observable
final class CreateArenaViewModel {
    var name = ""
    var mode: ArenaMode = .budgetGuardian
    var target = 300.0
    var stake = 10.0
    var vice: SpendingCategory = .coffee
    var endDate = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    private(set) var isCreating = false
    var errorMessage: String?

    static let stakeOptions: [Double] = [0, 5, 10, 20, 50]

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && endDate > .now && (!mode.usesTarget || target > 0)
    }

    /// Teen mode: no stakes, no Vice Streak and no Drinks.
    func configure(for stage: LifeStage) {
        guard stage == .teen else { return }
        stake = 0
        if !ArenaMode.teenModes.contains(mode) { mode = .mostImproved }
        if vice == .drinks { vice = .coffee }
    }

    func create(model: AppModel) async -> Arena? {
        isCreating = true
        defer { isCreating = false }
        do {
            let arena = try await model.services.arenas.create(
                name: name.trimmingCharacters(in: .whitespaces),
                mode: mode,
                target: mode.usesTarget ? target : 0,
                stake: model.isTeen ? 0 : stake,
                vice: mode == .viceStreak ? vice : nil,
                endDate: endDate
            )
            await model.refreshSavings()
            return arena
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

@Observable
final class JoinArenaViewModel {
    var code = "" {
        didSet {
            let digits = String(code.filter(\.isNumber).prefix(6))
            if digits != code { code = digits }
            if code.count < 6 { preview = nil; errorMessage = nil }
        }
    }
    private(set) var preview: Arena?
    private(set) var isWorking = false
    var errorMessage: String?

    func lookUp(model: AppModel) async {
        guard code.count == 6 else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let found = try await model.services.arenas.preview(code: code)
            if model.isTeen, let reason = Self.teenBlockReason(found) {
                preview = nil
                errorMessage = reason
                return
            }
            preview = found
            errorMessage = nil
        } catch {
            preview = nil
            errorMessage = error.localizedDescription
        }
    }

    /// Teens can only join arenas without money, in a teen mode.
    static func teenBlockReason(_ arena: Arena) -> String? {
        if !arena.isMoneyFree { return "Teen accounts can only join arenas without money. Ask your friend to start one with no stake." }
        if !ArenaMode.teenModes.contains(arena.mode) { return "\(arena.mode.title) isn't available in Teen mode." }
        return nil
    }

    func join(model: AppModel) async -> Arena? {
        isWorking = true
        defer { isWorking = false }
        do {
            let arena = try await model.services.arenas.join(code: code)
            await model.refreshSavings()
            return arena
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
