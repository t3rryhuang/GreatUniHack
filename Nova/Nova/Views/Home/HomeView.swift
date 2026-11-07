import SwiftUI

/// Home: today's predictions, weather, morning briefing, week ahead and alerts.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            NovaScreen {
                if !model.hasData {
                    NoDataView()
                } else if viewModel.isLoading && viewModel.briefing == nil {
                    LoadingCard()
                } else {
                    if let briefing = viewModel.briefing {
                        WeatherHero(briefing: briefing)
                    }
                    if let readiness = model.readiness {
                        NavigationLink { ReadinessView() } label: { ReadinessSummaryCard(snapshot: readiness) }
                            .buttonStyle(.plain)
                        if let quest = readiness.quest {
                            DailyQuestCard(quest: quest, streak: readiness.streak, recentShield: readiness.recentShield)
                        }
                        if let boss = readiness.boss {
                            WeeklyBossCard(boss: boss)
                        }
                    }
                    if model.isTeen {
                        NavigationLink { MoneyQuestHubView() } label: {
                            RowLink(title: "Money Quest", subtitle: "\(model.game.pointsToday()) of \(MoneyQuestConfig.dailyPointsCap) points today · play a 2-minute level", symbol: "gamecontroller.fill")
                        }
                        .buttonStyle(.plain)
                        NavigationLink { FamilyView() } label: {
                            RowLink(title: "Family", subtitle: "Loans and shared bills with someone you trust", symbol: "person.2.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    if let briefing = viewModel.briefing {
                        BriefingCard(briefing: briefing)
                    }
                    TodayPredictions(prediction: viewModel.weekAhead.first)
                    WeekAheadCard(viewModel: viewModel)
                    ForEach(viewModel.alerts) { alert in
                        AlertCard(alert: alert)
                    }
                    TalkToNovaCard()
                }
            }
            .navigationTitle("Home")
            .profileToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.showAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel("Add transaction")
                }
            }
            .refreshable { await viewModel.load(model: model, force: true) }
            .task(id: model.dataVersion) { await viewModel.load(model: model) }
        }
    }
}

/// Purple band with greeting, weather and today's expected spend.
private struct WeatherHero: View {
    let briefing: MorningBriefing

    var body: some View {
        NovaBrandBand {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(briefing.greeting)
                        .font(.novaTitle)
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.novaCallout)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Image(systemName: briefing.weather.condition.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.title)
                        .accessibilityHidden(true)
                    Text("\(briefing.weather.temperatureC)°C")
                        .font(.novaHeadline)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(briefing.weather.temperatureC) degrees, \(briefing.weather.condition.label), \(briefing.weather.city)")
            }
            Divider().overlay(.white.opacity(0.3))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Expected spend today").font(.novaCallout).foregroundStyle(.white.opacity(0.8))
                Text(briefing.expectedSpend.gbp)
                    .font(.novaHero)
                    .monospacedDigit()
                Text(briefing.weather.spendingImpact)
                    .font(.novaCallout)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// Compact morning briefing with play/pause. Ported from MorningBriefing.tsx.
private struct BriefingCard: View {
    @Environment(AppModel.self) private var model
    let briefing: MorningBriefing

    var body: some View {
        let isSpeaking = model.services.voice.isSpeaking
        NovaCard {
            SectionHeader(title: "Morning briefing", systemImage: "sun.horizon.fill") {
                Button("Open") { model.showBriefing = true }
                    .font(.novaCallout)
            }
            Text(briefing.nudge)
                .font(.novaBody)
                .foregroundStyle(NovaColor.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.sm) {
                Button {
                    guard model.require(.voiceBriefing) else { return }
                    if isSpeaking { model.services.voice.stopSpeaking() } else { model.services.voice.speak(briefing.script) }
                } label: {
                    Label(isSpeaking ? "Pause" : "Listen", systemImage: isSpeaking ? "pause.fill" : "play.fill")
                }
                .buttonStyle(NovaChipStyle(isSelected: isSpeaking))
                SoundWave(isActive: isSpeaking)
                Spacer()
                if !model.isPro {
                    Image(systemName: "lock.fill").foregroundStyle(NovaColor.muted).accessibilityLabel("Pro feature")
                }
            }
        }
    }
}

private struct TodayPredictions: View {
    let prediction: DayPrediction?

    var body: some View {
        NovaCard {
            SectionHeader(title: "Today's predictions", systemImage: "sparkles")
            if let prediction, !prediction.items.isEmpty {
                ForEach(prediction.items) { item in
                    PredictionRow(item: item)
                }
            } else {
                Text("No regular spending expected today.")
                    .font(.novaBody).foregroundStyle(NovaColor.body)
            }
        }
    }
}

/// Week-ahead calendar strip. Ported from the Home calendar.
private struct WeekAheadCard: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        NovaCard {
            SectionHeader(title: "Week ahead", systemImage: "calendar")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(viewModel.weekAhead) { day in
                        let isSelected = day.date == viewModel.selectedPrediction?.date
                        Button {
                            viewModel.selectedDay = day.date
                        } label: {
                            VStack(spacing: Spacing.xxs) {
                                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.novaCaption)
                                Text(day.date.formatted(.dateTime.day()))
                                    .font(.novaHeadline)
                                Text(day.totalExpected.gbpWhole)
                                    .font(.novaMicro)
                                    .monospacedDigit()
                            }
                            .foregroundStyle(isSelected ? NovaColor.onAction : NovaColor.heading)
                            .frame(minWidth: 56, minHeight: 76)
                            .padding(.horizontal, Spacing.xxs)
                            .background(isSelected ? NovaColor.action : NovaColor.tonal,
                                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide).day().month())), about \(day.totalExpected.gbpWhole)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            if let selected = viewModel.selectedPrediction {
                ForEach(selected.items) { item in
                    PredictionRow(item: item)
                }
            }
        }
    }
}

/// Spending alert card. Ported from SpendingAlert.tsx.
struct AlertCard: View {
    let alert: SpendingAlert

    var body: some View {
        NovaNotice(kind: alert.kind == .spike ? .warning : .info, title: alert.title, message: alert.message)
    }
}

/// Entry point to the Ask Nova chat.
private struct TalkToNovaCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            if model.require(.aiChat) { model.showChat = true }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.title2)
                    .foregroundStyle(NovaColor.onAction)
                    .frame(width: 52, height: 52)
                    .background(NovaColor.action, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Nova").font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    Text("Ask about your spending by text or voice").font(.novaCallout).foregroundStyle(NovaColor.body)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(NovaColor.muted).accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .background(NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(NovaColor.hairline))
        }
        .buttonStyle(.plain)
    }
}

/// Animated bars shown while the briefing is playing. Ported from SoundWave.tsx.
/// Holds still when Reduce Motion is on.
struct SoundWave: View {
    let isActive: Bool
    var tint: Color = NovaColor.action
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !isActive || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(tint)
                        .frame(width: 3, height: isActive ? 6 + 14 * abs(sin(t * 4 + Double(index))) : 6)
                }
            }
            .frame(height: 22)
        }
        .accessibilityHidden(true)
    }
}
