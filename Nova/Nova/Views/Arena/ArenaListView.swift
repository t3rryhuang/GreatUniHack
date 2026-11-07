import SwiftUI

/// Arena tab: savings challenges with friends, with stakes in pounds held in
/// your NatWest savings account.
struct ArenaListView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = ArenaListViewModel()
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var path: [Arena] = []
    @AppStorage("nova.arenaIntroSeen") private var introSeen = false

    var body: some View {
        NavigationStack(path: $path) {
            NovaScreen {
                ArenaHero(account: model.savingsAccount)
                HStack(spacing: Spacing.sm) {
                    Button {
                        if model.require(.arenaCreate) { showCreate = true }
                    } label: {
                        Label("Create", systemImage: "plus")
                    }
                    .buttonStyle(.novaPrimary)
                    Button {
                        showJoin = true
                    } label: {
                        Label("Join", systemImage: "number")
                    }
                    .buttonStyle(.novaSecondary)
                }

                if viewModel.isLoading {
                    LoadingCard(label: "Loading your arenas…")
                }
                if !viewModel.active.isEmpty {
                    Text("Active").overline().padding(.top, Spacing.xs)
                    ForEach(viewModel.active) { arena in
                        NavigationLink(value: arena) { ArenaRow(arena: arena) }
                            .buttonStyle(.plain)
                    }
                }
                if !viewModel.completed.isEmpty {
                    Text("Finished").overline().padding(.top, Spacing.xs)
                    ForEach(viewModel.completed) { arena in
                        NavigationLink(value: arena) { ArenaRow(arena: arena) }
                            .buttonStyle(.plain)
                    }
                }
                if !viewModel.isLoading && viewModel.arenas.isEmpty {
                    NovaCard {
                        Text("No arenas yet. Create one or join a friend's with a 6-digit code.")
                            .font(.novaBody).foregroundStyle(NovaColor.body)
                    }
                }
            }
            .navigationTitle("Arena")
            .profileToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { introSeen = false } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("How arenas work")
                }
            }
            .navigationDestination(for: Arena.self) { arena in
                ArenaDetailView(arena: arena) { viewModel.upsert($0) }
            }
            .refreshable { await viewModel.load(model: model) }
            .task { await viewModel.load(model: model) }
            .sheet(isPresented: $showCreate) {
                CreateArenaView { arena in
                    viewModel.upsert(arena)
                    path.append(arena)
                }
            }
            .sheet(isPresented: $showJoin) {
                JoinArenaView { arena in
                    viewModel.upsert(arena)
                    path.append(arena)
                }
            }
            .sheet(isPresented: Binding(get: { !introSeen }, set: { if !$0 { introSeen = true } })) {
                ArenaIntroView { introSeen = true }
            }
        }
    }
}

/// Purple band showing the savings account that holds stakes.
private struct ArenaHero: View {
    let account: SavingsAccount?

    var body: some View {
        NovaBrandBand {
            Label("Arena", systemImage: "trophy.fill").font(.novaHeadline)
            Text("Save with friends. Winner takes the pot.")
                .font(.novaTitle)
                .fixedSize(horizontal: false, vertical: true)
            if let account {
                Divider().overlay(.white.opacity(0.3))
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(account.name) \(account.maskedNumber)").font(.novaCallout).foregroundStyle(.white.opacity(0.8))
                        Text(account.balance.gbp).font(.novaSection).monospacedDigit()
                    }
                    Spacer()
                    Image(systemName: "building.columns.fill").font(.title2).accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct ArenaRow: View {
    let arena: Arena

    var body: some View {
        let me = arena.members.first(where: \.isCurrentUser)
        let rank = ArenaRules.standings(for: arena).firstIndex { $0.isCurrentUser }.map { $0 + 1 }
        NovaCard {
            HStack(spacing: Spacing.sm) {
                Image(systemName: arena.mode.symbol)
                    .font(.title3)
                    .foregroundStyle(NovaColor.action)
                    .frame(width: 44, height: 44)
                    .background(NovaColor.lilac, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(arena.name).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    Text("\(arena.mode.title) · \(arena.members.count) members").font(.novaCaption).foregroundStyle(NovaColor.body)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(arena.prizePot.gbpWhole).font(.novaHeadline).foregroundStyle(NovaColor.brandText).monospacedDigit()
                    Text("pot").font(.novaCaption).foregroundStyle(NovaColor.body)
                }
            }
            if arena.status == .completed {
                let won = arena.winnerID != nil && arena.winnerID == me?.id
                Label(won ? "You won" : "Finished", systemImage: won ? "crown.fill" : "flag.checkered")
                    .font(.novaCallout.weight(.semibold))
                    .foregroundStyle(won ? NovaColor.success : NovaColor.body)
            } else {
                ProbabilityBar(value: arena.progress)
                HStack {
                    Text(arena.daysLeft == 0 ? "Ready to settle" : "\(arena.daysLeft) days left")
                    Spacer()
                    if let rank { Text("You're #\(rank)") }
                }
                .font(.novaCaption)
                .foregroundStyle(NovaColor.body)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// First-visit explainer. Ported from arena-onboarding.tsx.
private struct ArenaIntroView: View {
    let done: () -> Void

    var body: some View {
        NavigationStack {
            NovaScreen {
                Text("Save more together. Each arena has a goal, a pot and an end date.")
                    .font(.novaBody).foregroundStyle(NovaColor.body)
                ForEach(ArenaMode.allCases) { mode in
                    NovaCard {
                        Label(mode.title, systemImage: mode.symbol).font(.novaHeadline).foregroundStyle(NovaColor.brandText)
                        Text(mode.rule).font(.novaCallout).foregroundStyle(NovaColor.body)
                    }
                }
                NovaNotice(
                    kind: .info,
                    title: "Your stake stays at NatWest",
                    message: "When you join, your stake moves from your Flexible Saver into the arena pot. The winner's pot is paid straight back into their savings account."
                )
                Button("Got it", action: done).buttonStyle(.novaPrimary)
            }
            .navigationTitle("How arenas work")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
}
