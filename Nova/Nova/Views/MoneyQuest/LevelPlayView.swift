import SwiftUI

/// One Money Quest level: life events and quick questions, with a virtual character
/// whose five stats use the same bars as the real Readiness screen.
struct LevelPlayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: LevelPlayViewModel

    init(level: QuestLevel, chapter: QuestChapter) {
        _viewModel = State(initialValue: LevelPlayViewModel(level: level, chapter: chapter))
    }

    var body: some View {
        NovaScreen {
            if viewModel.isFinished {
                summary
            } else if let step = viewModel.step {
                header
                if viewModel.stepIndex == 0 {
                    Label(viewModel.level.persona, systemImage: "person.fill")
                        .font(.novaCallout).foregroundStyle(NovaColor.body)
                }
                VirtualCharacterCard(stats: viewModel.stats, budget: viewModel.budget)
                stepCard(step)
                    .id(step.id)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.stepIndex)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.chosen)
        .navigationTitle(viewModel.level.title)
        .navigationBarTitleDisplayMode(.inline)
        #if DEBUG
        .task {
            // -NovaAutoplay plays the level with the first right/best answers (for testing and screenshots).
            guard ProcessInfo.processInfo.arguments.contains("-NovaAutoplay") else { return }
            while !viewModel.isFinished, let step = viewModel.step {
                try? await Task.sleep(for: .milliseconds(700))
                viewModel.choose(step.options.firstIndex { $0.correct == true } ?? 0)
                try? await Task.sleep(for: .milliseconds(700))
                await viewModel.next(model: model)
            }
        }
        #endif
        .sheet(item: Binding(get: { viewModel.askNovaTopic.map(TopicItem.init) }, set: { if $0 == nil { viewModel.askNovaTopic = nil } })) { item in
            ChatView(initialDraft: item.text)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Step \(viewModel.stepIndex + 1) of \(viewModel.level.steps.count)").font(.novaCaption).foregroundStyle(NovaColor.body)
            ProbabilityBar(value: viewModel.progress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(viewModel.stepIndex + 1) of \(viewModel.level.steps.count)")
    }

    @ViewBuilder private func stepCard(_ step: QuestStep) -> some View {
        NovaCard {
            Label(step.kind == .event ? "Life event" : "Quick question",
                  systemImage: step.kind == .event ? "sparkles" : "questionmark.circle.fill")
                .font(.novaCaption.weight(.semibold))
                .foregroundStyle(NovaColor.action)
            Text(viewModel.text(step.prompt))
                .font(.novaSection).foregroundStyle(NovaColor.heading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(step.options.enumerated()), id: \.offset) { index, option in
                OptionButton(text: viewModel.text(option.text), index: index, count: step.options.count,
                             state: optionState(step, index)) {
                    viewModel.choose(index)
                }
            }
            if let option = viewModel.chosenOption {
                feedback(step, option)
            }
        }
    }

    private func optionState(_ step: QuestStep, _ index: Int) -> OptionButton.State {
        guard let chosen = viewModel.chosen else { return .idle }
        if step.kind == .question {
            if step.options[index].correct == true { return .correct }
            return index == chosen ? .wrong : .dimmed
        }
        return index == chosen ? .chosen : .dimmed
    }

    @ViewBuilder private func feedback(_ step: QuestStep, _ option: QuestOption) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if step.kind == .question {
                Label(option.correct == true ? "That's right" : "Not quite", systemImage: option.correct == true ? "checkmark.circle.fill" : "info.circle.fill")
                    .font(.novaHeadline)
                    .foregroundStyle(option.correct == true ? NovaColor.success : NovaColor.info)
            }
            Text(viewModel.text(option.explanation)).font(.novaBody).foregroundStyle(NovaColor.body)
                .fixedSize(horizontal: false, vertical: true)
            let changes = option.statChanges
            if !changes.isEmpty || option.moneyChange != 0 {
                FlowChips(items: changes.map { "\($0.1 > 0 ? "+" : "")\($0.1) \($0.0.title)" }
                          + (option.moneyChange != 0 ? ["\(option.moneyChange > 0 ? "+" : "−")£\(abs(option.moneyChange)) budget"] : []))
            }
            HStack(spacing: Spacing.sm) {
                Button { viewModel.askNova() } label: { Label("Ask Nova about this", systemImage: "bubble.left.fill") }
                    .buttonStyle(NovaChipStyle())
                Spacer(minLength: 0)
            }
            Button(viewModel.stepIndex + 1 < viewModel.level.steps.count ? "Next" : "Finish level") {
                Task { await viewModel.next(model: model) }
            }
            .buttonStyle(.novaPrimary)
        }
        .padding(Spacing.sm)
        .background(NovaColor.tonal, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: viewModel.reward?.newBadgeChapter != nil ? "rosette" : "flag.checkered")
                    .font(.system(size: 56)).foregroundStyle(NovaColor.chartYolk).accessibilityHidden(true)
                Text("Level complete").font(.novaTitle).foregroundStyle(NovaColor.brandText)
                if viewModel.level.questionCount > 0 {
                    Text("\(viewModel.correctAnswers) of \(viewModel.level.questionCount) questions right")
                        .font(.novaCallout).foregroundStyle(NovaColor.body)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            NovaCard {
                SectionHeader(title: "What you learned", systemImage: "lightbulb.fill")
                ForEach(viewModel.level.learned, id: \.self) { line in
                    Label(viewModel.text(line), systemImage: "circle.fill").labelStyle(BulletLabelStyle())
                }
            }
            if let reward = viewModel.reward {
                NovaCard {
                    SectionHeader(title: "Rewards", systemImage: "star.fill")
                    Label("+\(reward.pointsEarned) points", systemImage: "star.circle.fill").font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    if reward.hitDailyCap {
                        Text("You've reached today's \(MoneyQuestConfig.dailyPointsCap)-point cap. Keep playing for fun; points start again tomorrow.")
                            .font(.novaCaption).foregroundStyle(NovaColor.body)
                    }
                    Text(reward.countsForWisdom ? "This level raised your Wisdom stat." : "Wisdom counts up to \(MoneyQuestConfig.wisdomLevelsPerDay) new levels a day.")
                        .font(.novaCallout).foregroundStyle(NovaColor.body)
                    if let chapter = reward.newBadgeChapter {
                        Label("Chapter \(chapter) badge earned!", systemImage: "rosette").font(.novaHeadline).foregroundStyle(NovaColor.chartYolk)
                    }
                }
            }
            Button("Play again") { viewModel.reset() }.buttonStyle(.novaSecondary)
            Button("Back to chapter") { dismiss() }.buttonStyle(.novaPrimary)
        }
    }
}

private struct TopicItem: Identifiable {
    let text: String
    var id: String { text }
}

/// A large answer button. Never timed.
private struct OptionButton: View {
    enum State { case idle, chosen, correct, wrong, dimmed }
    let text: String
    let index: Int
    let count: Int
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text(text).font(.novaBody).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let icon { Image(systemName: icon).font(.title3).accessibilityHidden(true) }
            }
            .foregroundStyle(foreground)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(border, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .accessibilityLabel("Option \(index + 1) of \(count): \(text)")
        .accessibilityValue(accessibilityState)
    }

    private var icon: String? {
        switch state {
        case .correct: "checkmark.circle.fill"
        case .wrong: "xmark.circle.fill"
        case .chosen: "hand.point.up.left.fill"
        default: nil
        }
    }

    private var foreground: Color {
        switch state {
        case .dimmed: NovaColor.body
        case .correct: NovaColor.success
        case .wrong: NovaColor.error
        default: NovaColor.heading
        }
    }

    private var background: Color {
        switch state {
        case .correct: NovaColor.successTint
        case .wrong: NovaColor.errorTint
        case .chosen: NovaColor.lilac
        default: NovaColor.card
        }
    }

    private var border: Color {
        switch state {
        case .idle: NovaColor.action
        case .correct: NovaColor.success
        case .wrong: NovaColor.error
        case .chosen: NovaColor.action
        case .dimmed: NovaColor.hairline
        }
    }

    private var accessibilityState: String {
        switch state {
        case .correct: "Correct answer"
        case .wrong: "Your answer, not correct"
        case .chosen: "Your choice"
        default: ""
        }
    }
}

/// The virtual character: same budget for everyone, same stat bars as the real Readiness screen.
private struct VirtualCharacterCard: View {
    let stats: [ReadinessStat: Int]
    let budget: Double

    var body: some View {
        NovaCard {
            HStack {
                Text("Your character").font(.novaHeadline).foregroundStyle(NovaColor.brandText)
                Spacer()
                Label("\(budget.gbpWhole) left", systemImage: "sterlingsign.circle.fill")
                    .font(.novaCallout.weight(.semibold)).foregroundStyle(NovaColor.action)
                    .accessibilityLabel("Virtual budget, \(budget.gbpWhole) left")
            }
            ForEach(ReadinessStat.allCases) { stat in
                let value = stats[stat] ?? MoneyQuestConfig.startingStat
                HStack(spacing: Spacing.xs) {
                    Image(systemName: stat.symbol).foregroundStyle(NovaColor.action).frame(width: 22).accessibilityHidden(true)
                    Text(stat.title).font(.novaCaption).foregroundStyle(NovaColor.heading).frame(minWidth: 80, alignment: .leading)
                    ProbabilityBar(value: Double(value) / Double(ReadinessStat.maxPoints))
                    Text("\(value)").font(.novaCaption.weight(.semibold)).monospacedDigit().foregroundStyle(NovaColor.heading)
                        .frame(minWidth: 30, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(stat.title)
                .accessibilityValue("\(value) of \(ReadinessStat.maxPoints)")
            }
            Text("Everyone starts with the same \(MoneyQuestConfig.monthlyBudget.gbpWhole) a month.").font(.novaMicro).foregroundStyle(NovaColor.muted)
        }
    }
}

/// Simple wrapping chips for stat changes.
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.xs) { chips }
            VStack(alignment: .leading, spacing: Spacing.xs) { chips }
        }
    }

    @ViewBuilder private var chips: some View {
        ForEach(items, id: \.self) { item in
            Text(item)
                .font(.novaCaption.weight(.semibold))
                .foregroundStyle(item.hasPrefix("-") || item.hasPrefix("−") ? NovaColor.error : NovaColor.success)
                .padding(.horizontal, Spacing.xs).padding(.vertical, 4)
                .background(NovaColor.card, in: Capsule())
        }
    }
}
