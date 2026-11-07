import SwiftUI

/// Nova Explorer: Manchester. Teen mode only (there's no entry point in Adult mode).
struct ExplorerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = ExplorerViewModel()

    var body: some View {
        ZStack {
            if model.isTeen {
                ExplorerSceneView(viewModel: viewModel, model: model, reduceMotion: reduceMotion)
                    .ignoresSafeArea()
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in
                                // Swipe anywhere outside the controls to look around.
                                viewModel.cameraDrag += SIMD2(Float(value.velocity.width) * 0.016, Float(value.velocity.height) * 0.016)
                            }
                    )
                    .accessibilityHidden(true)
                if viewModel.isLoaded { hud } else { loading }
                if viewModel.stylistOpen { StylistPanel(viewModel: viewModel).transition(.move(edge: .bottom)) }
            } else {
                NovaScreen {
                    NovaNotice(kind: .info, title: "Teen mode only", message: "Nova Explorer is part of Teen mode for 16 and 17-year-olds.")
                    Button("Close") { dismiss() }.buttonStyle(.novaPrimary)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.stylistOpen)
        .task { if model.isTeen { await viewModel.load(model: model); await openDebugPanel() } }
        .onDisappear { model.services.voice.stopSpeaking() }
        .sheet(item: $viewModel.panel) { panel in
            ExplorerPanelView(panel: panel, viewModel: viewModel)
        }
        .statusBarHidden()
    }

    private var loading: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView().tint(.white)
            Text("Loading Manchester…").font(.novaHeadline).foregroundStyle(.white)
        }
        .padding(Spacing.lg)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.card))
    }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: Spacing.xs) {
            topBar
            ForEach(Array(viewModel.toasts.enumerated()), id: \.offset) { _, toast in
                Text(toast)
                    .font(.novaCallout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.xs)
                    .background(Color(red: 0.24, green: 0.06, blue: 0.33).opacity(0.92), in: Capsule())
                    .transition(.opacity)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            Spacer()
            if !viewModel.stylistOpen {
                if let prompt = interactPrompt {
                    Button { viewModel.interact(model: model) } label: {
                        Label(prompt, systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.novaHeadline)
                            .padding(.horizontal, Spacing.lg).frame(minHeight: 50)
                            .background(.white, in: Capsule())
                            .foregroundStyle(NovaColor.action)
                    }
                    .accessibilityHint("Starts the conversation")
                }
                controls
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .animation(.easeInOut(duration: 0.2), value: viewModel.toasts)
    }

    private var interactPrompt: String? {
        if let npc = viewModel.nearbyNPC { return "Talk to \(npc.name)" }
        if viewModel.nearbyBillboard != nil { return "Read billboard" }
        return nil
    }

    private var topBar: some View {
        let p = model.explorer
        let xpInLevel = p.xp % ExplorerEconomy.xpPerLevel
        return HStack(spacing: Spacing.sm) {
            Button { dismiss() } label: { hudIcon("xmark") }.accessibilityLabel("Leave Nova Explorer")
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.zone.title).font(.novaCaption.weight(.semibold)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: Spacing.xs) {
                    Text("Lv \(p.level)").font(.novaCaption.weight(.bold)).foregroundStyle(.white).fixedSize()
                    ProbabilityBar(value: Double(xpInLevel) / Double(ExplorerEconomy.xpPerLevel), tint: Color(red: 0.95, green: 0.76, blue: 0.19))
                        .frame(width: 70)
                    Label("\(p.coins)", systemImage: "circle.hexagongrid.fill").font(.novaCaption.weight(.semibold)).foregroundStyle(Color(red: 0.99, green: 0.82, blue: 0.4))
                        .fixedSize()
                }
            }
            .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: Radius.control))
            .layoutPriority(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(viewModel.zone.title). Level \(p.level), \(xpInLevel) of \(ExplorerEconomy.xpPerLevel) XP to the next level, \(p.coins) Nova Coins")
            Spacer()
            Button { viewModel.panel = .travel } label: { hudIcon("map.fill") }.accessibilityLabel("Travel and quest list")
            Button { viewModel.panel = .wardrobe } label: { hudIcon("tshirt.fill") }.accessibilityLabel("Wardrobe and emotes")
            Button { viewModel.toggleCamera(model: model) } label: { hudIcon(viewModel.thirdPerson ? "person.fill.viewfinder" : "eye.fill") }
                .accessibilityLabel(viewModel.thirdPerson ? "Switch to first person" : "Switch to third person")
        }
    }

    private var controls: some View {
        HStack(alignment: .bottom) {
            Joystick(value: $viewModel.joystick)
            Spacer()
            VStack(spacing: Spacing.sm) {
                Button { viewModel.jumpRequested = true } label: { roundButton("arrow.up", size: 64) }
                    .accessibilityLabel("Jump")
                Button { viewModel.interact(model: model) } label: { roundButton("hand.tap.fill", size: 54) }
                    .accessibilityLabel(interactPrompt ?? "Interact")
                    .disabled(interactPrompt == nil)
                    .opacity(interactPrompt == nil ? 0.45 : 1)
            }
        }
    }

    private func hudIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.black.opacity(0.45), in: Circle())
    }

    private func roundButton(_ symbol: String, size: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.title2.weight(.bold))
            .foregroundStyle(NovaColor.action)
            .frame(width: size, height: size)
            .background(.white.opacity(0.92), in: Circle())
            .shadow(radius: 3)
    }

    /// DEBUG: `-NovaExplorerOpen budget|scam|tram|market|park|billboard|wardrobe|travel` opens a panel for screenshots.
    private func openDebugPanel() async {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-NovaExplorerTour"), !model.explorer.avatarConfirmed {
            await viewModel.ask("curly black hair and a teal hoodie with white trainers", model: model)
            await viewModel.confirmLook(model: model)
        }
        guard let i = args.firstIndex(of: "-NovaExplorerOpen"), i + 1 < args.count else { return }
        if !model.explorer.avatarConfirmed, args[i + 1] != "stylist" { await viewModel.confirmLook(model: model) }
        try? await Task.sleep(for: .seconds(1.5))
        let byActivity: [String: String] = ["budget": "priya", "scam": "sam", "tram": "lou", "market": "zee", "park": "jo", "money": "vic"]
        switch args[i + 1] {
        case "billboard": viewModel.panel = .billboard(.park)
        case "wardrobe": viewModel.panel = .wardrobe
        case "travel": viewModel.panel = .travel
        case "stylist":
            if let reply = args.firstIndex(of: "-NovaStylistSay").map({ args[$0 + 1] }) { await viewModel.ask(reply, model: model) }
        default:
            if let id = byActivity[args[i + 1]], let npc = ExplorerWorld.npcs.first(where: { $0.id == id }) { viewModel.panel = .quest(npc) }
        }
        #endif
    }
}

/// Virtual joystick. VoiceOver users can use the Travel menu instead (every quest is reachable from it).
private struct Joystick: View {
    @Binding var value: SIMD2<Float>
    @State private var knob: CGSize = .zero
    private let radius: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.35)).frame(width: radius * 2, height: radius * 2)
            Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2).frame(width: radius * 2, height: radius * 2)
            Circle().fill(.white.opacity(0.9)).frame(width: 52, height: 52).offset(knob)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    var v = drag.translation
                    let length = sqrt(v.width * v.width + v.height * v.height)
                    if length > radius { v = CGSize(width: v.width / length * radius, height: v.height / length * radius) }
                    knob = v
                    value = SIMD2(Float(v.width / radius), Float(-v.height / radius))
                }
                .onEnded { _ in
                    knob = .zero
                    value = .zero
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Movement joystick")
        .accessibilityHint("Drag to walk. Or use the Travel menu at the top to go straight to a place or quest.")
    }
}

/// Remi's styling panel: what Remi says, suggestion chips, push-to-talk, a manual editor and "This is me".
private struct StylistPanel: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: ExplorerViewModel

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.title3).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.9, green: 0.41, blue: 0.61), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remi, stylist").font(.novaCaption.weight(.semibold)).foregroundStyle(NovaColor.body)
                        Text(viewModel.remiLine).font(.novaBody).foregroundStyle(NovaColor.heading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer(minLength: 0)
                    if viewModel.isThinking { ProgressView() }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(StylistRules.suggestions, id: \.self) { chip in
                            Button(chip) { Task { await viewModel.ask(chip, model: model) } }
                                .buttonStyle(NovaChipStyle())
                        }
                    }
                }
                HStack(spacing: Spacing.sm) {
                    PushToTalkButton(isListening: viewModel.isListening,
                                     start: { viewModel.startListening(model: model) },
                                     stop: { viewModel.stopListening(model: model) })
                    Button { viewModel.panel = .manualEditor } label: { Label("Edit", systemImage: "slider.horizontal.3") }
                        .buttonStyle(NovaChipStyle())
                    Spacer()
                    if model.explorer.avatarConfirmed {
                        Button("Cancel") { viewModel.cancelStylist(model: model) }.font(.novaCallout)
                    }
                }
                Button { Task { await viewModel.confirmLook(model: model) } } label: {
                    Label("This is me", systemImage: "checkmark")
                }
                .buttonStyle(.novaPrimary)
                Text("Say colours and styles, like 'curly black hair and a teal hoodie'. Remi never asks for personal details.")
                    .font(.novaMicro).foregroundStyle(NovaColor.muted)
            }
            .padding(Spacing.md)
            .background(NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.promo, style: .continuous))
            .padding(Spacing.sm)
        }
    }
}

/// Hold to talk; release to send.
private struct PushToTalkButton: View {
    let isListening: Bool
    let start: () -> Void
    let stop: () -> Void

    var body: some View {
        Label(isListening ? "Listening…" : "Hold to talk", systemImage: isListening ? "waveform" : "mic.fill")
            .font(.novaCallout.weight(.semibold))
            .foregroundStyle(isListening ? NovaColor.onAction : NovaColor.action)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 44)
            .background(isListening ? NovaColor.action : NovaColor.lilac, in: Capsule())
            .onLongPressGesture(minimumDuration: 0.05, maximumDistance: 60, perform: {}, onPressingChanged: { pressing in
                pressing ? start() : stop()
            })
            .accessibilityElement()
            .accessibilityLabel(isListening ? "Listening" : "Talk to Remi")
            .accessibilityHint("Double-tap to start talking, double-tap again to send")
            .accessibilityAction { isListening ? stop() : start() }
    }
}
