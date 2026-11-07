import SwiftUI

/// Arena detail: standings, member spending, invite code, sync and settle.
struct ArenaDetailView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: ArenaDetailViewModel
    let onChange: (Arena) -> Void

    init(arena: Arena, onChange: @escaping (Arena) -> Void) {
        _viewModel = State(initialValue: ArenaDetailViewModel(arena: arena))
        self.onChange = onChange
    }

    var body: some View {
        let arena = viewModel.arena
        NovaScreen {
            NovaBrandBand {
                Label(arena.mode.title, systemImage: arena.mode.symbol).font(.novaCallout)
                if arena.isMoneyFree {
                    Text("Points and badges").font(.novaTitle)
                    Text("No money changes hands · \(arena.members.count) members")
                        .font(.novaCallout).foregroundStyle(.white.opacity(0.85))
                } else {
                    Text(arena.prizePot.gbp).font(.novaHero).monospacedDigit()
                    Text("Prize pot · \(arena.stakeAmount.gbpWhole) each from \(arena.members.count) members")
                        .font(.novaCallout).foregroundStyle(.white.opacity(0.85))
                }
                ProbabilityBar(value: arena.progress, tint: .white)
                Text(arena.status == .completed ? "Finished" : "\(arena.daysLeft) days left · ends \(arena.endDate.formatted(.dateTime.day().month(.wide)))")
                    .font(.novaCaption).foregroundStyle(.white.opacity(0.85))
            }

            NovaCard {
                SectionHeader(title: "Rules", systemImage: "list.bullet.clipboard")
                Text(arena.mode.rule).font(.novaCallout).foregroundStyle(NovaColor.body)
                if arena.mode == .viceStreak, let vice = arena.viceCategory {
                    Label("Vice: \(vice.rawValue)", systemImage: vice.symbol).font(.novaCallout).foregroundStyle(NovaColor.heading)
                } else if arena.mode == .mostImproved {
                    Text("Compared with: your own previous period").font(.novaCallout).foregroundStyle(NovaColor.heading)
                } else if arena.isTeenArena {
                    Text(arena.mode == .budgetGuardian ? "Limit: your own usual spending" : "Target: 10% of your own income")
                        .font(.novaCallout).foregroundStyle(NovaColor.heading)
                    Text("Teen arena: standings show % and ranks only, never anyone's £.").font(.novaCaption).foregroundStyle(NovaColor.muted)
                } else {
                    Text("\(arena.mode.targetLabel): \(arena.targetAmount.gbpWhole)").font(.novaCallout).foregroundStyle(NovaColor.heading)
                }
            }

            StandingsCard(arena: arena, standings: viewModel.standings)

            if arena.status != .completed {
                NovaCard {
                    SectionHeader(title: "Invite friends", systemImage: "person.2.fill")
                    HStack {
                        Text(arena.joinCode)
                            .font(.system(.title, design: .monospaced).weight(.semibold))
                            .foregroundStyle(NovaColor.brandText)
                            .accessibilityLabel("Join code \(arena.joinCode.map(String.init).joined(separator: " "))")
                        Spacer()
                        ShareLink(item: "Join my Nova savings arena \"\(arena.name)\" with code \(arena.joinCode)") {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(NovaChipStyle())
                    }
                }

                Button {
                    Task {
                        await viewModel.sync(model: model)
                        onChange(viewModel.arena)
                    }
                } label: {
                    if viewModel.isSyncing { ProgressView() } else { Label("Sync my spending", systemImage: "arrow.triangle.2.circlepath") }
                }
                .buttonStyle(.novaSecondary)
                .disabled(viewModel.isSyncing)

                if let reason = ArenaRules.blockReason(arena) {
                    Text(reason).font(.novaCaption).foregroundStyle(NovaColor.muted).frame(maxWidth: .infinity)
                } else {
                    Button {
                        Task {
                            await viewModel.settle(model: model)
                            onChange(viewModel.arena)
                        }
                    } label: {
                        if viewModel.isSettling { ProgressView().tint(NovaColor.onAction) } else { Text(arena.isMoneyFree ? "Finish and see results" : "Settle and pay the winner") }
                    }
                    .buttonStyle(.novaPrimary)
                    .disabled(viewModel.isSettling)
                }
            } else {
                Button("See results") {
                    viewModel.settlement = ArenaSettlement(
                        arenaID: arena.id,
                        winner: arena.members.first { $0.id == arena.winnerID },
                        standings: viewModel.standings,
                        payout: arena.prizePot,
                        reference: "NW-ARENA-\(arena.joinCode)",
                        settledAt: arena.endDate
                    )
                }
                .buttonStyle(.novaPrimary)
            }
        }
        .navigationTitle(arena.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.sync(model: model) }
        .sheet(item: Binding(
            get: { viewModel.settlement.map(SettlementItem.init) },
            set: { if $0 == nil { viewModel.settlement = nil } }
        )) { item in
            ArenaResultsView(arena: viewModel.arena, settlement: item.settlement)
        }
    }
}

private struct SettlementItem: Identifiable {
    let settlement: ArenaSettlement
    var id: UUID { settlement.arenaID }
}

private struct StandingsCard: View {
    let arena: Arena
    let standings: [ArenaMember]

    var body: some View {
        NovaCard {
            SectionHeader(title: "Standings", systemImage: "list.number")
            ForEach(Array(standings.enumerated()), id: \.element.id) { index, member in
                HStack(spacing: Spacing.sm) {
                    Text("\(index + 1)")
                        .font(.novaHeadline)
                        .foregroundStyle(index == 0 ? NovaColor.action : NovaColor.muted)
                        .frame(width: 24)
                    AvatarView(initials: member.initials, size: 40, highlighted: member.isCurrentUser)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.isCurrentUser ? "\(member.name) (you)" : member.name)
                            .font(.novaBody.weight(member.isCurrentUser ? .semibold : .regular))
                            .foregroundStyle(member.isEliminated ? NovaColor.muted : NovaColor.heading)
                            .strikethrough(member.isEliminated)
                        status(for: member)
                    }
                    Spacer()
                    Text(value(for: member))
                        .font(.novaHeadline)
                        .foregroundStyle(NovaColor.heading)
                        .monospacedDigit()
                }
                .frame(minHeight: 48)
                .accessibilityElement(children: .combine)
                if arena.mode == .budgetGuardian || arena.mode == .savingsSprint {
                    ProbabilityBar(
                        value: progress(for: member),
                        tint: progress(for: member) > 1 && arena.mode == .budgetGuardian ? NovaColor.error : NovaColor.action
                    )
                    .padding(.leading, 76)
                }
            }
        }
    }

    private func value(for member: ArenaMember) -> String {
        ArenaResultsView.value(for: member, in: arena)
    }

    private func progress(for member: ArenaMember) -> Double {
        if arena.isTeenArena {
            switch arena.mode {
            case .budgetGuardian: return member.baselineSpend.map { $0 > 0 ? member.currentSpend / $0 : 0 } ?? 0
            case .savingsSprint: return member.ownTargetProgress ?? 0
            default: return 0
            }
        }
        guard arena.targetAmount > 0 else { return 0 }
        return (arena.mode == .savingsSprint ? member.currentSavings : member.currentSpend) / arena.targetAmount
    }

    @ViewBuilder private func status(for member: ArenaMember) -> some View {
        if member.isEliminated {
            Text("Out").font(.novaCaption).foregroundStyle(NovaColor.error)
        } else if ArenaRules.isAtRisk(member, in: arena) && (arena.targetAmount > 0 || arena.isTeenArena) {
            Text("Close to the limit").font(.novaCaption).foregroundStyle(NovaColor.warning)
        } else if let synced = member.lastSyncedAt {
            Text("Synced \(synced.formatted(.relative(presentation: .named)))").font(.novaCaption).foregroundStyle(NovaColor.body)
        }
    }
}

/// Results and pay-out. Ported from arena-results.tsx; the Solana transaction
/// is replaced by a NatWest transfer reference.
struct ArenaResultsView: View {
    @Environment(\.dismiss) private var dismiss
    let arena: Arena
    let settlement: ArenaSettlement

    var body: some View {
        NavigationStack {
            NovaScreen {
                let won = settlement.winner?.isCurrentUser == true
                VStack(spacing: Spacing.sm) {
                    Image(systemName: won ? "crown.fill" : "flag.checkered")
                        .font(.system(size: 56))
                        .foregroundStyle(won ? NovaColor.chartYolk : NovaColor.action)
                        .accessibilityHidden(true)
                    Text(won ? "You won!" : "\(settlement.winner?.name ?? "Nobody") won")
                        .font(.novaTitle).foregroundStyle(NovaColor.brandText)
                    Text(settlement.payout <= 0
                         ? (won ? "You earn points and a winner's badge. No money changes hands." : "The winner earns points and a badge. No money changes hands.")
                         : won
                         ? "\(settlement.payout.gbp) has been paid into your Flexible Saver."
                         : "\(settlement.payout.gbp) has been paid to the winner's savings account.")
                        .font(.novaBody).foregroundStyle(NovaColor.body).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)

                NovaCard {
                    SectionHeader(title: "Final standings", systemImage: "list.number")
                    ForEach(Array(settlement.standings.enumerated()), id: \.element.id) { index, member in
                        HStack {
                            Text("\(index + 1).").font(.novaHeadline).foregroundStyle(NovaColor.muted)
                            Text(member.isCurrentUser ? "\(member.name) (you)" : member.name).font(.novaBody).foregroundStyle(NovaColor.heading)
                            Spacer()
                            Text(Self.value(for: member, in: arena))
                                .font(.novaBody).monospacedDigit().foregroundStyle(NovaColor.heading)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if settlement.payout > 0 {
                    NovaCard {
                        SectionHeader(title: "Payment", systemImage: "building.columns.fill")
                        Metric(label: "Reference", value: settlement.reference)
                        Metric(label: "Settled", value: settlement.settledAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                Button("Done") { dismiss() }.buttonStyle(.novaPrimary)
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// The figure shown next to a member: saved, spent, or % cut for Most Improved.
    static func value(for member: ArenaMember, in arena: Arena) -> String {
        if arena.isTeenArena { return ArenaRules.teenValue(for: member, in: arena) }
        return switch arena.mode {
        case .savingsSprint: member.currentSavings.gbpWhole
        case .mostImproved: member.reduction.map { "\($0 >= 0 ? "−" : "+")\(abs($0).percent)" } ?? "–"
        case .budgetGuardian, .viceStreak: member.currentSpend.gbp
        }
    }
}
