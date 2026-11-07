import Charts
import SwiftUI

/// Money Readiness: the character, the 0-1000 score, five stats, streak and a 30-day chart.
struct ReadinessView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = ReadinessViewModel()

    var body: some View {
        NovaScreen {
            if let snapshot = model.readiness {
                hero(snapshot)
                StreakCard(snapshot: snapshot)
                NovaCard {
                    SectionHeader(title: "Your stats", systemImage: "chart.bar.doc.horizontal")
                    ForEach(snapshot.score.stats) { stat in
                        Button { viewModel.open(stat.stat, model: model) } label: { StatBarRow(score: stat) }
                            .buttonStyle(.plain)
                    }
                    Text("Tap a stat to see what it measures and how to raise it.")
                        .font(.novaCaption).foregroundStyle(NovaColor.muted)
                }
                ScoreHistoryCard(history: snapshot.history, change: snapshot.monthChange)
                if model.isTeen {
                    NavigationLink { GraduationView() } label: {
                        RowLink(title: "Road to 18", subtitle: "Your graduation checklist and Readiness Report", symbol: "graduationcap.fill")
                    }
                    .buttonStyle(.plain)
                }
                ReadinessDisclaimer()
            } else if model.hasData {
                LoadingCard(label: "Working out your score…")
            } else {
                NoDataView()
            }
        }
        .navigationTitle("Readiness")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refreshReadiness() }
        .sheet(item: $viewModel.selectedStat) { stat in
            StatDetailSheet(stat: stat, viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }

    private func hero(_ snapshot: ReadinessSnapshot) -> some View {
        let score = snapshot.score
        return NovaCard(padding: Spacing.lg) {
            VStack(spacing: Spacing.md) {
                ReadinessCharacter(rank: score.rank, size: 116)
                RingView(progress: Double(score.total) / 1000, lineWidth: 12, tint: score.rank.color) {
                    VStack(spacing: 0) {
                        Text("\(score.total)").font(.novaHero).foregroundStyle(NovaColor.heading).monospacedDigit()
                        Text("of 1000").font(.novaCaption).foregroundStyle(NovaColor.body)
                    }
                }
                .frame(width: 150, height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Readiness Score")
                .accessibilityValue("\(score.total) of 1000")
                VStack(spacing: Spacing.xxs) {
                    Text("\(score.rank.title) \(score.rank.characterTitle)").font(.novaSection).foregroundStyle(NovaColor.brandText)
                    if let (next, gap) = viewModel.pointsToNextRank(score) {
                        Text("\(gap) points to \(next.title)").font(.novaCallout).foregroundStyle(NovaColor.body)
                    } else {
                        Text("Top rank reached").font(.novaCallout).foregroundStyle(NovaColor.body)
                    }
                }
                .accessibilityElement(children: .combine)
                ReadinessDisclaimer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Streak and shields.
private struct StreakCard: View {
    let snapshot: ReadinessSnapshot

    var body: some View {
        HStack(spacing: Spacing.sm) {
            tile(value: "\(snapshot.streak)", label: "day streak", symbol: "flame.fill", tint: NovaColor.chartTangerine)
            tile(value: "\(snapshot.shieldsLeft)", label: snapshot.shieldsLeft == 1 ? "shield left" : "shields left", symbol: "shield.lefthalf.filled", tint: NovaColor.chartBlueberry)
            tile(value: "\(snapshot.longestStreak)", label: "best streak", symbol: "trophy.fill", tint: NovaColor.chartYolk)
        }
    }

    private func tile(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint).accessibilityHidden(true)
            Text(value).font(.novaSection).foregroundStyle(NovaColor.heading).monospacedDigit()
            Text(label).font(.novaCaption).foregroundStyle(NovaColor.body).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .padding(.vertical, Spacing.xs)
        .background(NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(NovaColor.hairline))
        .accessibilityElement(children: .combine)
    }
}

/// Score over the last 30 days.
private struct ScoreHistoryCard: View {
    let history: [DailyScore]
    let change: Int

    var body: some View {
        NovaCard {
            SectionHeader(title: "Last 30 days", systemImage: "chart.line.uptrend.xyaxis") {
                if change != 0 {
                    Text("\(change > 0 ? "+" : "")\(change)")
                        .font(.novaHeadline)
                        .foregroundStyle(change > 0 ? NovaColor.success : NovaColor.error)
                }
            }
            if history.count < 2 {
                Text("Your chart fills in as you use Nova each day.").font(.novaCallout).foregroundStyle(NovaColor.body)
            } else {
                let low = max(0, (history.map(\.total).min() ?? 0) - 40)
                let high = min(1000, (history.map(\.total).max() ?? 1000) + 40)
                Chart(history) { day in
                    AreaMark(x: .value("Day", day.date), yStart: .value("Floor", low), yEnd: .value("Score", day.total))
                        .foregroundStyle(NovaColor.action.opacity(0.12))
                    LineMark(x: .value("Day", day.date), y: .value("Score", day.total))
                        .foregroundStyle(NovaColor.action)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .accessibilityLabel(day.date.formatted(.dateTime.day().month()))
                        .accessibilityValue("\(day.total)")
                }
                .chartYScale(domain: low...high)
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                .frame(height: 160)
                .accessibilityLabel("Readiness Score over the last 30 days")
                .accessibilityValue("From \(history.first?.total ?? 0) to \(history.last?.total ?? 0)")
            }
        }
    }
}

/// What a stat measures, its real-world equivalent and how to raise it.
private struct StatDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let stat: ReadinessStat
    @Bindable var viewModel: ReadinessViewModel

    var body: some View {
        NavigationStack {
            NovaScreen {
                let score = model.readiness?.score.stats.first { $0.stat == stat }
                HStack(spacing: Spacing.md) {
                    Image(systemName: stat.symbol)
                        .font(.title)
                        .foregroundStyle(NovaColor.action)
                        .frame(width: 60, height: 60)
                        .background(NovaColor.lilac, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(score?.points ?? 0) / \(ReadinessStat.maxPoints)").font(.novaTitle).foregroundStyle(NovaColor.heading).monospacedDigit()
                        Text(score?.detail ?? "").font(.novaCallout).foregroundStyle(NovaColor.body)
                    }
                }
                .accessibilityElement(children: .combine)
                NovaCard {
                    SectionHeader(title: "What it measures", systemImage: "magnifyingglass")
                    Text(stat.measures).font(.novaBody).foregroundStyle(NovaColor.body)
                }
                NovaCard {
                    SectionHeader(title: "Real-world equivalent", systemImage: "building.columns")
                    Text("\(stat.creditFactor). Lenders look at something similar when you apply for your first credit product.")
                        .font(.novaBody).foregroundStyle(NovaColor.body)
                }
                NovaCard {
                    SectionHeader(title: "How to raise it", systemImage: "arrow.up.circle")
                    Text(stat.howToRaise).font(.novaBody).foregroundStyle(NovaColor.body)
                }
                if stat == .balance { limitEditor }
                ReadinessDisclaimer()
            }
            .navigationTitle(stat.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var limitEditor: some View {
        NovaCard {
            SectionHeader(title: "Your weekly limit", systemImage: "slider.horizontal.3")
            Stepper(value: $viewModel.limitDraft, in: 5...1_000, step: 5) {
                Text(viewModel.limitDraft.gbpWhole).font(.novaSection).foregroundStyle(NovaColor.heading).monospacedDigit()
            }
            .accessibilityLabel("Weekly limit")
            .accessibilityValue(viewModel.limitDraft.gbpWhole)
            Text(model.readinessProgress.weeklyLimit == nil ? "Using your 8-week average." : "Using your own limit.")
                .font(.novaCaption).foregroundStyle(NovaColor.muted)
            HStack(spacing: Spacing.sm) {
                Button("Save limit") { Task { await viewModel.saveLimit(model: model) } }
                    .buttonStyle(.novaPrimary)
                Button("Use average") { Task { await viewModel.useAverageLimit(model: model) } }
                    .buttonStyle(.novaSecondary)
            }
        }
    }
}

/// A tappable card row that leads to another screen.
struct RowLink: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(NovaColor.onAction)
                .frame(width: 48, height: 48)
                .background(NovaColor.action, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                Text(subtitle).font(.novaCallout).foregroundStyle(NovaColor.body)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(NovaColor.muted).accessibilityHidden(true)
        }
        .padding(Spacing.md)
        .background(NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(NovaColor.hairline))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
