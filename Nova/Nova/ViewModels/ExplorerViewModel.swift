import Foundation
import Observation

/// Nova Explorer game state shared by the 3D scene and the SwiftUI HUD.
/// The scene reads input every frame; the HUD only re-renders when something it shows changes.
@Observable
final class ExplorerViewModel {
    enum Panel: Identifiable, Equatable {
        case quest(ExplorerNPC)
        case billboard(BillboardKind)
        case wardrobe
        case travel
        case manualEditor

        var id: String {
            switch self {
            case .quest(let npc): "quest-\(npc.id)"
            case .billboard(let kind): "billboard-\(kind.rawValue)"
            case .wardrobe: "wardrobe"
            case .travel: "travel"
            case .manualEditor: "editor"
            }
        }
    }

    // MARK: Input (read by the scene every frame; not observed)

    @ObservationIgnored var joystick: SIMD2<Float> = .zero
    @ObservationIgnored var jumpRequested = false
    @ObservationIgnored var cameraDrag: SIMD2<Float> = .zero
    @ObservationIgnored var teleport: SIMD2<Float>?
    @ObservationIgnored var emoteRequest: Emote?

    // MARK: Shown in the HUD

    private(set) var zone: ExplorerZone = .venue
    private(set) var nearbyNPC: ExplorerNPC?
    private(set) var nearbyBillboard: BillboardKind?
    var thirdPerson = true
    var panel: Panel?
    private(set) var toasts: [String] = []
    private(set) var isLoaded = false

    // MARK: Remi (stylist)

    var stylistOpen = false
    private(set) var previewLook = AvatarLook()
    private(set) var remiLine = StylistRules.greeting
    private(set) var stylistHistory: [StylistTurn] = []
    private(set) var isListening = false
    private(set) var isThinking = false
    private(set) var suggestConfirm = false
    /// Bumps when the player's look or cosmetic changes, so the scene rebuilds the avatar.
    private(set) var lookVersion = 0
    /// Bumps when the park or billboards need redrawing.
    private(set) var worldVersion = 0

    var currentLook: AvatarLook = AvatarLook()
    var cosmetic: String?

    // MARK: Loading

    func load(model: AppModel) async {
        let rewards = await model.loadExplorer()
        currentLook = model.explorer.look
        previewLook = currentLook
        cosmetic = model.explorer.equippedCosmetic
        thirdPerson = model.explorer.thirdPerson
        lookVersion += 1
        worldVersion += 1
        isLoaded = true
        if rewards.count == 1, let reward = rewards.first {
            showToast(reward.xp > 0 ? "\(reward.title): +\(reward.xp) XP" : "\(reward.title) (today's XP cap reached)")
        } else if rewards.count > 1 {
            showToast("Savings sync: +\(rewards.reduce(0) { $0 + $1.xp }) XP from your Piggy Bank and saving streak")
        }
        if !model.explorer.avatarConfirmed { openStylist(model: model) }
    }

    // MARK: Scene callbacks

    func sceneUpdated(zone: ExplorerZone, npc: ExplorerNPC?, billboard: BillboardKind?) {
        if zone != self.zone { self.zone = zone }
        if npc?.id != nearbyNPC?.id { nearbyNPC = npc }
        if billboard != nearbyBillboard { nearbyBillboard = billboard }
    }

    // MARK: Actions

    func interact(model: AppModel) {
        if let npc = nearbyNPC {
            if npc.activity == .stylist { openStylist(model: model) } else { panel = .quest(npc) }
        } else if let board = nearbyBillboard {
            panel = .billboard(board)
        }
    }

    func travel(to zone: ExplorerZone) {
        teleport = zone.spawn
        panel = nil
    }

    func talk(to npc: ExplorerNPC, model: AppModel) {
        teleport = npc.position + SIMD2(0, 1.6)
        panel = nil
        if npc.activity == .stylist { openStylist(model: model) } else {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                panel = .quest(npc)
            }
        }
    }

    func toggleCamera(model: AppModel) {
        thirdPerson.toggle()
        var p = model.explorer
        p.thirdPerson = thirdPerson
        Task { await model.saveExplorer(p) }
    }

    func showToast(_ text: String) {
        toasts.append(text)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            if !toasts.isEmpty { toasts.removeFirst() }
        }
    }

    func worldChanged() { worldVersion += 1 }

    // MARK: Stylist

    func openStylist(model: AppModel) {
        previewLook = currentLook
        stylistOpen = true
        remiLine = model.explorer.avatarConfirmed ? "Back for a new look? Tell me what you'd like." : StylistRules.greeting
        model.services.voice.speak(remiLine)
    }

    func ask(_ text: String, model: AppModel) async {
        let message = StylistGuard.cleanInput(text)
        guard !message.isEmpty, !isThinking else { return }
        isThinking = true
        defer { isThinking = false }
        stylistHistory.append(StylistTurn(role: "user", text: message))
        let reply = await model.services.stylist.reply(to: message, current: previewLook, history: stylistHistory)
        stylistHistory.append(StylistTurn(role: "assistant", text: reply.text))
        stylistHistory = Array(stylistHistory.suffix(12))
        previewLook = previewLook.applying(reply.patch)
        suggestConfirm = reply.suggestsConfirm
        remiLine = reply.text
        lookVersion += 1
        model.services.voice.speak(reply.text)
    }

    /// Push-to-talk: start on press, stop on release; the transcript goes to Remi.
    func startListening(model: AppModel) {
        guard !isListening else { return }
        isListening = true
        model.services.voice.stopSpeaking()
        Task { @MainActor in
            defer { isListening = false }
            if let text = try? await model.services.voice.transcribe(context: .stylist), !text.isEmpty {
                await ask(text, model: model)
            } else {
                remiLine = "Sorry, I didn't catch that. Try again or tap a suggestion."
            }
        }
    }

    func stopListening(model: AppModel) {
        model.services.voice.stopListening()
    }

    func setPreview(_ look: AvatarLook) {
        previewLook = look
        lookVersion += 1
    }

    func confirmLook(model: AppModel) async {
        currentLook = previewLook
        var p = model.explorer
        let firstTime = !p.avatarConfirmed
        p.look = previewLook
        p.avatarConfirmed = true
        await model.saveExplorer(p)
        stylistOpen = false
        lookVersion += 1
        model.services.voice.speak(firstTime ? "Looking great! Go and explore Manchester. Talk to people with a speech bubble to start quests." : "Fresh look! Enjoy.")
        if firstTime { showToast("Talk to Priya and Sam in the hall to start your first quests") }
    }

    func cancelStylist(model: AppModel) {
        previewLook = currentLook
        lookVersion += 1
        stylistOpen = !model.explorer.avatarConfirmed
        model.services.voice.stopSpeaking()
    }

    // MARK: Wardrobe

    func buy(_ item: Cosmetic, model: AppModel) async {
        var p = model.explorer
        guard !p.ownedCosmetics.contains(item.id), p.coins >= item.cost, CosmeticCatalogue.isUnlocked(item, progress: p) else { return }
        p.coins -= item.cost
        p.ownedCosmetics.append(item.id)
        p.equippedCosmetic = item.id
        await model.saveExplorer(p)
        cosmetic = item.id
        lookVersion += 1
        showToast("\(item.title) unlocked")
    }

    func equip(_ id: String?, model: AppModel) async {
        var p = model.explorer
        p.equippedCosmetic = CosmeticCatalogue.validate(id)
        await model.saveExplorer(p)
        cosmetic = p.equippedCosmetic
        lookVersion += 1
    }

    func play(_ emote: Emote) {
        emoteRequest = emote
        panel = nil
    }

    // MARK: Quests

    /// Finishes a quest: XP (daily cap), coins, a park point and badges.
    func complete(_ questID: String, isMoneyQuest: Bool, badge: String? = nil, model: AppModel) async {
        let reward = await model.completeExplorerQuest(questID, isMoneyQuest: isMoneyQuest, badge: badge)
        if reward.xp > 0 {
            showToast("Quest complete: +\(reward.xp) XP\(reward.coins > 0 ? ", +\(reward.coins) coins" : "")")
        } else {
            showToast("Quest complete! You've reached today's XP cap, so play on just for fun.")
        }
        worldVersion += 1
    }

    func contributeToPark(model: AppModel) async {
        do {
            let points = try await model.contributeToPark()
            showToast("You gave \(points) point\(points == 1 ? "" : "s") to the Community Park. Thank you!")
            worldVersion += 1
        } catch {
            showToast(model.explorer.parkTokens == 0 ? "Finish a quest to earn park points." : "You've given today's 3 points. Come back tomorrow!")
        }
    }

    /// The next quest the player hasn't done yet (for the billboard).
    func nextQuest(model: AppModel) -> ExplorerNPC? {
        ExplorerWorld.npcs.first { npc in npc.questID.map { !model.explorer.completedQuests.contains($0) } ?? false }
    }
}
