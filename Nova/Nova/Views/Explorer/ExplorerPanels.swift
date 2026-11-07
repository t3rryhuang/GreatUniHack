import SwiftUI

/// Every 2D panel in Nova Explorer. Quests use large buttons and no timers.
struct ExplorerPanelView: View {
    let panel: ExplorerViewModel.Panel
    @Bindable var viewModel: ExplorerViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch panel {
                case .quest(let npc): QuestPanel(npc: npc, viewModel: viewModel)
                case .billboard(let kind): BillboardPanel(kind: kind, viewModel: viewModel)
                case .wardrobe: WardrobePanel(viewModel: viewModel)
                case .travel: TravelPanel(viewModel: viewModel)
                case .manualEditor: ManualEditor(viewModel: viewModel)
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { viewModel.panel = nil } } }
        }
        .presentationDetents([.large])
    }
}

// MARK: Quests

private struct QuestPanel: View {
    @Environment(AppModel.self) private var model
    let npc: ExplorerNPC
    @Bindable var viewModel: ExplorerViewModel

    var body: some View {
        NovaScreen {
            NPCHeader(npc: npc, done: npc.questID.map { model.explorer.completedQuests.contains($0) } ?? false)
            switch npc.activity {
            case .budgetHackathon: BudgetQuest(viewModel: viewModel)
            case .scamSpotter: ScamQuest(viewModel: viewModel)
            case .tramTicket: TramQuest(viewModel: viewModel)
            case .marketplace: MarketQuest(viewModel: viewModel)
            case .communityPark: ParkPanel(viewModel: viewModel)
            case .moneyQuest(let chapter): MoneyQuestChapter(npc: npc, chapterID: chapter, viewModel: viewModel)
            case .stylist: EmptyView()
            }
        }
        .navigationTitle(npc.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.services.voice.speak(npc.line) }
    }
}

private struct NPCHeader: View {
    let npc: ExplorerNPC
    let done: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(String(npc.name.prefix(1)))
                .font(.novaTitle).foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color(UIColor(hex: npc.look.topColour.hex)), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(npc.name), \(npc.role.lowercased())").font(.novaCaption.weight(.semibold)).foregroundStyle(NovaColor.body)
                Text("“\(npc.line)”").font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if done { Image(systemName: "checkmark.seal.fill").foregroundStyle(NovaColor.success).accessibilityLabel("Done before") }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shared result card with the reward button.
private struct QuestResult: View {
    let passed: Bool
    let lines: [String]
    let complete: () -> Void
    @State private var collected = false

    var body: some View {
        NovaCard {
            Label(passed ? "Quest passed" : "Not quite, try again", systemImage: passed ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                .font(.novaHeadline).foregroundStyle(passed ? NovaColor.success : NovaColor.info)
            ForEach(lines, id: \.self) { Label($0, systemImage: "circle.fill").labelStyle(BulletLabelStyle()) }
            if passed {
                Button(collected ? "Reward collected" : "Collect reward") {
                    collected = true
                    complete()
                }
                .buttonStyle(.novaPrimary)
                .disabled(collected)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct BudgetQuest: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: ExplorerViewModel
    @State private var snacks = 20.0
    @State private var tools = 35.0
    @State private var savings = 5.0
    @State private var result: (passed: Bool, notes: [String])?

    var body: some View {
        let total = snacks + tools + savings
        NovaCard {
            SectionHeader(title: "The Budgeting Hackathon", systemImage: "laptopcomputer")
            Text("Your team has \(ExplorerQuestRules.hackathonBudget.gbpWhole) for the weekend. Split it between three pots.")
                .font(.novaBody).foregroundStyle(NovaColor.body)
            slider("Team snacks", "fork.knife", $snacks)
            slider("Hardware tools", "wrench.and.screwdriver.fill", $tools)
            slider("Emergency savings", "lifepreserver.fill", $savings)
            HStack {
                Text("Total").font(.novaHeadline)
                Spacer()
                Text("\(total.gbpWhole) of \(ExplorerQuestRules.hackathonBudget.gbpWhole)")
                    .font(.novaHeadline).monospacedDigit()
                    .foregroundStyle(abs(total - ExplorerQuestRules.hackathonBudget) < 0.5 ? NovaColor.success : NovaColor.error)
            }
            .accessibilityElement(children: .combine)
            Button("Check my split") { result = ExplorerQuestRules.checkBudget(snacks: snacks, tools: tools, savings: savings) }
                .buttonStyle(.novaSecondary)
        }
        if let result {
            QuestResult(passed: result.passed, lines: result.notes) {
                Task { await viewModel.complete("budget", isMoneyQuest: false, model: model) }
            }
        }
    }

    private func slider(_ title: String, _ symbol: String, _ value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label(title, systemImage: symbol).font(.novaCallout)
                Spacer()
                Text(value.wrappedValue.gbpWhole).font(.novaCallout.weight(.semibold)).monospacedDigit()
            }
            Slider(value: value, in: 0...ExplorerQuestRules.hackathonBudget, step: 1) { Text(title) }
                .accessibilityValue(value.wrappedValue.gbpWhole)
        }
    }
}

private struct ScamQuest: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: ExplorerViewModel
    @State private var answers: [Int: Bool] = [:]
    @State private var checked = false

    var body: some View {
        let result = ExplorerQuestRules.checkScams(answers)
        NovaCard {
            SectionHeader(title: "The Scam Spotter", systemImage: "exclamationmark.shield.fill")
            Text("Sponsors left these offers at the desk. Mark each one safe or a scam.").font(.novaBody).foregroundStyle(NovaColor.body)
        }
        ForEach(ExplorerQuestRules.sponsorOffers) { offer in
            NovaCard {
                Text("“\(offer.text)”").font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.sm) {
                    choice("Safe", "checkmark.shield.fill", offer: offer, value: true)
                    choice("Scam", "xmark.shield.fill", offer: offer, value: false)
                }
                if checked, let answer = answers[offer.id] {
                    Label(offer.explanation, systemImage: answer == offer.isSafe ? "checkmark.circle.fill" : "info.circle.fill")
                        .font(.novaCallout).foregroundStyle(answer == offer.isSafe ? NovaColor.success : NovaColor.info)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        Button("Check my answers") { checked = true }
            .buttonStyle(.novaSecondary)
            .disabled(answers.count < ExplorerQuestRules.sponsorOffers.count)
        if checked {
            QuestResult(passed: result.passed,
                        lines: ["\(result.correct) of \(ExplorerQuestRules.sponsorOffers.count) right.",
                                result.spottedMule ? "You spotted the money mule trap." : "Look again at the offer to move money through your account."]) {
                Task { await viewModel.complete("scam", isMoneyQuest: false, badge: "scam", model: model) }
            }
        }
    }

    private func choice(_ title: String, _ symbol: String, offer: ExplorerQuestRules.Offer, value: Bool) -> some View {
        Button { answers[offer.id] = value; checked = false } label: { Label(title, systemImage: symbol).frame(maxWidth: .infinity) }
            .buttonStyle(NovaChipStyle(isSelected: answers[offer.id] == value))
            .accessibilityValue(answers[offer.id] == value ? "Selected" : "")
    }
}

private struct TramQuest: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: ExplorerViewModel
    @State private var picks: [Int: ExplorerQuestRules.Ticket] = [:]

    var body: some View {
        let correct = ExplorerQuestRules.tramTrips.filter { picks[$0.id] == ExplorerQuestRules.cheapest(for: $0) }.count
        NovaCard {
            SectionHeader(title: "The Tram Ticket Challenge", systemImage: "tram.fill")
            Text("Example fares: single \(TramFares.single.gbp), day pass \(TramFares.day.gbp), weekly pass \(TramFares.week.gbp). Pick the cheapest ticket for each week.")
                .font(.novaBody).foregroundStyle(NovaColor.body)
            Text("These are example fares for the game, not real Bee Network prices.").font(.novaCaption).foregroundStyle(NovaColor.muted)
        }
        ForEach(ExplorerQuestRules.tramTrips) { trip in
            NovaCard {
                Text(trip.story).font(.novaHeadline).foregroundStyle(NovaColor.heading).fixedSize(horizontal: false, vertical: true)
                ForEach(ExplorerQuestRules.Ticket.allCases) { ticket in
                    Button { picks[trip.id] = ticket } label: {
                        HStack {
                            Text(ticket.title)
                            Spacer()
                            if picks[trip.id] != nil { Text(ExplorerQuestRules.cost(ticket, for: trip).gbp).monospacedDigit() }
                        }
                        .padding(.horizontal, Spacing.sm).frame(minHeight: 44)
                        .background(picks[trip.id] == ticket ? NovaColor.lilac : NovaColor.tonal, in: RoundedRectangle(cornerRadius: Radius.control))
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(picks[trip.id] == ticket ? "Selected" : "")
                }
                if let pick = picks[trip.id] {
                    let best = ExplorerQuestRules.cheapest(for: trip)
                    Text(pick == best ? "Cheapest! You pay \(ExplorerQuestRules.cost(best, for: trip).gbp)." : "\(best.title) would be cheaper: \(ExplorerQuestRules.cost(best, for: trip).gbp).")
                        .font(.novaCallout).foregroundStyle(pick == best ? NovaColor.success : NovaColor.info)
                }
            }
        }
        if picks.count == ExplorerQuestRules.tramTrips.count {
            QuestResult(passed: correct >= 2, lines: ["\(correct) of \(ExplorerQuestRules.tramTrips.count) cheapest tickets found.",
                                                      "Count your trips first, then compare: a pass only pays off if you travel enough."]) {
                Task { await viewModel.complete("tram", isMoneyQuest: false, model: model) }
            }
        }
    }
}

private struct MarketQuest: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: ExplorerViewModel
    @State private var basket: Set<Int> = []
    @State private var checked = false

    var body: some View {
        let result = ExplorerQuestRules.checkMarket(basket)
        NovaCard {
            SectionHeader(title: "Needs vs Wants Marketplace", systemImage: "basket.fill")
            Text("You have \(ExplorerQuestRules.marketBudget.gbpWhole) for the week. Fill your basket: needs first, then a want if it fits.")
                .font(.novaBody).foregroundStyle(NovaColor.body)
            HStack {
                Text("Basket").font(.novaHeadline)
                Spacer()
                Text("\(result.total.gbp) of \(ExplorerQuestRules.marketBudget.gbpWhole)").font(.novaHeadline).monospacedDigit()
                    .foregroundStyle(result.total <= ExplorerQuestRules.marketBudget ? NovaColor.heading : NovaColor.error)
            }
            .accessibilityElement(children: .combine)
        }
        ForEach(ExplorerQuestRules.marketItems) { item in
            Button {
                if basket.contains(item.id) { basket.remove(item.id) } else { basket.insert(item.id) }
                checked = false
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: item.symbol).frame(width: 32).foregroundStyle(NovaColor.action).accessibilityHidden(true)
                    Text(item.name).font(.novaBody).foregroundStyle(NovaColor.heading)
                    Spacer()
                    Text(item.price.gbp).monospacedDigit().foregroundStyle(NovaColor.body)
                    Image(systemName: basket.contains(item.id) ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(basket.contains(item.id) ? NovaColor.success : NovaColor.muted)
                }
                .padding(Spacing.sm).frame(minHeight: 52)
                .background(NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(NovaColor.hairline))
            }
            .buttonStyle(.plain)
            .accessibilityValue(basket.contains(item.id) ? "In basket" : "Not in basket")
        }
        Button("Check my basket") { checked = true }.buttonStyle(.novaSecondary)
        if checked {
            QuestResult(passed: result.passed,
                        lines: result.passed ? ["All your needs are covered and you're within budget."]
                        : (result.missingNeeds.isEmpty ? [] : ["Missing needs: \(result.missingNeeds.joined(separator: ", "))."])
                            + (result.total > ExplorerQuestRules.marketBudget ? ["You're \((result.total - ExplorerQuestRules.marketBudget).gbp) over budget."] : [])) {
                Task { await viewModel.complete("market", isMoneyQuest: false, model: model) }
            }
        }
    }
}

/// An NPC who hosts a Money Quest chapter: the existing levels, now played in the city.
private struct MoneyQuestChapter: View {
    @Environment(AppModel.self) private var model
    let npc: ExplorerNPC
    let chapterID: Int
    @Bindable var viewModel: ExplorerViewModel

    var body: some View {
        if let chapter = MoneyQuestContent.shared.chapters.first(where: { $0.id == chapterID }) {
            NovaCard {
                SectionHeader(title: "Money Quest, chapter \(chapter.id)", systemImage: chapter.symbol)
                Text(chapter.title).font(.novaSection).foregroundStyle(NovaColor.brandText)
                Text(chapter.summary).font(.novaCallout).foregroundStyle(NovaColor.body)
            }
            ForEach(Array(chapter.levels.enumerated()), id: \.element.id) { index, level in
                NavigationLink {
                    LevelPlayView(level: level, chapter: chapter) {
                        Task {
                            await viewModel.complete("mq:\(level.id)", isMoneyQuest: true, model: model)
                            if let id = npc.questID { await model.markExplorerQuest(id) }
                        }
                    }
                } label: {
                    RowLink(title: "Level \(index + 1): \(level.title)",
                            subtitle: model.game.isComplete(level.id) ? "Done · play again any time" : level.persona,
                            symbol: model.game.isComplete(level.id) ? "checkmark" : "play.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ParkPanel: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: ExplorerViewModel

    var body: some View {
        let status = model.park ?? ParkStatus(total: 0, contributors: 0)
        let stage = status.stage
        NovaCard {
            SectionHeader(title: "Community Park", systemImage: "tree.fill")
            Text("Everyone in Manchester builds this park together. It's now: \(stage.title.lowercased()).")
                .font(.novaBody).foregroundStyle(NovaColor.body)
            if let next = stage.next {
                ProbabilityBar(value: Double(status.total - stage.threshold) / Double(next.threshold - stage.threshold), tint: NovaColor.success)
                Text("\(status.total.formatted()) of \(next.threshold.formatted()) points to the \(next.title.lowercased())")
                    .font(.novaCallout.weight(.semibold)).foregroundStyle(NovaColor.heading)
            } else {
                Text("Finished! \(status.total.formatted()) points.").font(.novaCallout.weight(.semibold))
            }
            Text("\(status.contributors.formatted()) players have helped.").font(.novaCaption).foregroundStyle(NovaColor.body)
        }
        .accessibilityElement(children: .combine)
        NovaCard {
            SectionHeader(title: "Your park points", systemImage: "leaf.fill")
            Text("You have \(model.explorer.parkTokens) point\(model.explorer.parkTokens == 1 ? "" : "s"). Each finished quest earns one. You can give up to \(ExplorerEconomy.dailyParkPoints) a day; everyone has the same cap, whatever their money.")
                .font(.novaCallout).foregroundStyle(NovaColor.body)
            Button("Give my points") { Task { await viewModel.contributeToPark(model: model) } }
                .buttonStyle(.novaPrimary)
                .disabled(model.explorer.parkTokens == 0 || model.explorer.parkPointsToday() >= ExplorerEconomy.dailyParkPoints)
            Text("You've given \(model.explorer.parkContributed) in total.").font(.novaCaption).foregroundStyle(NovaColor.muted)
        }
        ForEach(ParkStage.allCases.dropFirst(), id: \.rawValue) { s in
            Label("\(s.title) at \(s.threshold.formatted()) points", systemImage: stage >= s ? "checkmark.circle.fill" : "circle")
                .font(.novaCallout).foregroundStyle(stage >= s ? NovaColor.success : NovaColor.body)
        }
    }
}

// MARK: Billboard, wardrobe, travel, editor

private struct BillboardPanel: View {
    @Environment(AppModel.self) private var model
    let kind: BillboardKind
    @Bindable var viewModel: ExplorerViewModel

    var body: some View {
        let content = BillboardContent(kind: kind, model: model, nextQuest: viewModel.nextQuest(model: model))
        NovaScreen {
            BillboardView(content: content)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(content.kicker). \(content.title). \(content.detail)")
        }
        .navigationTitle("Billboard")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WardrobePanel: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: ExplorerViewModel

    var body: some View {
        let p = model.explorer
        NovaScreen {
            NovaCard {
                HStack {
                    Label("\(p.coins) Nova Coins", systemImage: "circle.hexagongrid.fill").font(.novaHeadline)
                    Spacer()
                    Text("Level \(p.level) · \(p.xp) XP").font(.novaCallout).foregroundStyle(NovaColor.body)
                }
                Text("Coins are only earned by playing and saving towards your own goal. They can't be bought.")
                    .font(.novaCaption).foregroundStyle(NovaColor.muted)
            }
            NovaCard {
                SectionHeader(title: "Emotes", systemImage: "figure.wave")
                HStack {
                    ForEach(Emote.allCases) { emote in
                        Button { viewModel.play(emote) } label: { Label(emote.title, systemImage: emote.symbol).frame(maxWidth: .infinity) }
                            .buttonStyle(NovaChipStyle())
                    }
                }
            }
            NovaCard {
                SectionHeader(title: "Wardrobe", systemImage: "tshirt.fill")
                ForEach(CosmeticCatalogue.all) { item in
                    let owned = p.ownedCosmetics.contains(item.id)
                    let unlocked = CosmeticCatalogue.isUnlocked(item, progress: p)
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: unlocked ? item.symbol : "lock.fill").frame(width: 28).foregroundStyle(NovaColor.action).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.novaBody).foregroundStyle(NovaColor.heading)
                            if !unlocked, let badge = item.requiresBadge {
                                Text(badge == "saver" ? "Reach 100% of your Piggy Bank goal" : "Pass the Scam Spotter quest").font(.novaCaption).foregroundStyle(NovaColor.muted)
                            }
                        }
                        Spacer()
                        if owned {
                            Button(p.equippedCosmetic == item.id ? "Take off" : "Wear") {
                                Task { await viewModel.equip(p.equippedCosmetic == item.id ? nil : item.id, model: model) }
                            }
                            .buttonStyle(NovaChipStyle(isSelected: p.equippedCosmetic == item.id))
                        } else {
                            Button("\(item.cost) coins") { Task { await viewModel.buy(item, model: model) } }
                                .buttonStyle(NovaChipStyle())
                                .disabled(!unlocked || p.coins < item.cost)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            NovaCard {
                SectionHeader(title: "Badges", systemImage: "rosette")
                if p.badges.isEmpty { Text("Pass quests and reach savings goals to earn badges.").font(.novaCallout).foregroundStyle(NovaColor.body) }
                ForEach(p.badges, id: \.self) { badge in
                    Label(badge == "saver" ? "Saver: reached your own goal" : badge == "scam" ? "Scam spotter" : badge.capitalized, systemImage: "rosette")
                        .font(.novaCallout).foregroundStyle(NovaColor.chartYolk)
                }
            }
            Button("Restyle with Remi") {
                viewModel.panel = nil
                viewModel.openStylist(model: model)
            }
            .buttonStyle(.novaSecondary)
        }
        .navigationTitle("Wardrobe")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Travel and quest list: every place and quest in one accessible list (no joystick needed).
private struct TravelPanel: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: ExplorerViewModel

    var body: some View {
        List {
            Section("Go to") {
                ForEach(ExplorerZone.allCases) { zone in
                    Button { viewModel.travel(to: zone) } label: { Label(zone.title, systemImage: "location.fill") }
                }
            }
            Section("Quests") {
                ForEach(ExplorerWorld.npcs.filter { $0.activity != .stylist }) { npc in
                    Button { viewModel.talk(to: npc, model: model) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(npc.name), \(npc.role.lowercased())").font(.novaBody).foregroundStyle(NovaColor.heading)
                                Text(ExplorerZone.at(npc.position).title).font(.novaCaption).foregroundStyle(NovaColor.body)
                            }
                            Spacer()
                            if let id = npc.questID, model.explorer.completedQuests.contains(id) {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(NovaColor.success).accessibilityLabel("Done")
                            }
                        }
                    }
                }
            }
            Section("Remi") {
                Button { viewModel.talk(to: ExplorerWorld.npcs[0], model: model) } label: { Label("Change my look", systemImage: "sparkles") }
            }
        }
        .navigationTitle("Travel")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Manual fallback for the stylist: every option as a picker, with the live 3D preview behind.
private struct ManualEditor: View {
    @Bindable var viewModel: ExplorerViewModel

    var body: some View {
        let look = viewModel.previewLook
        Form {
            Picker("Skin", selection: binding(\.skin)) { ForEach(SkinTone.allCases) { Text($0.title).tag($0) } }
            Picker("Hair", selection: binding(\.hair)) { ForEach(HairStyle.allCases) { Text($0.title).tag($0) } }
            Picker("Hair colour", selection: binding(\.hairColour)) { ForEach(AvatarColour.allCases) { Text($0.title).tag($0) } }
            Picker("Top", selection: binding(\.top)) { ForEach(TopStyle.allCases) { Text($0.title).tag($0) } }
            Picker("Top colour", selection: binding(\.topColour)) { ForEach(AvatarColour.allCases) { Text($0.title).tag($0) } }
            Picker("Trousers colour", selection: binding(\.bottomColour)) { ForEach(AvatarColour.allCases) { Text($0.title).tag($0) } }
            Picker("Shoes", selection: binding(\.shoes)) { ForEach(ShoeStyle.allCases) { Text($0.title).tag($0) } }
            Picker("Shoe colour", selection: binding(\.shoeColour)) { ForEach(AvatarColour.allCases) { Text($0.title).tag($0) } }
            Picker("Accessory", selection: binding(\.accessory)) { ForEach(Accessory.allCases) { Text($0.title).tag($0) } }
            Section { Text(look.summary.capitalized).font(.novaCallout).foregroundStyle(NovaColor.body) }
        }
        .navigationTitle("Edit my look")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding<T>(_ path: WritableKeyPath<AvatarLook, T>) -> Binding<T> {
        Binding(get: { viewModel.previewLook[keyPath: path] },
                set: { value in var l = viewModel.previewLook; l[keyPath: path] = value; viewModel.setPreview(l) })
    }
}
