import SwiftUI

/// Scenario simulator: runway slider, what-if questions and budget tips.
struct SimulatorView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = SimulatorViewModel()
    @FocusState private var questionFocused: Bool

    var body: some View {
        NavigationStack {
            NovaScreen {
                if !model.hasData {
                    NoDataView()
                } else {
                    RunwaySliderCard(viewModel: viewModel, summary: model.summary)
                    askCard
                    ForEach(viewModel.results) { result in
                        ScenarioCard(result: result, isExpanded: viewModel.expanded.contains(result.id)) {
                            withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggle(result.id) }
                        }
                    }
                    TipsCard(tips: viewModel.tips)
                }
            }
            .navigationTitle("Simulator")
            .profileToolbar()
            .task(id: model.dataVersion) { await viewModel.loadTips(model: model) }
        }
    }

    private var askCard: some View {
        NovaCard {
            SectionHeader(title: "What if…?", systemImage: "questionmark.bubble.fill")
            Text("Ask about a change and Nova will estimate the effect on your money.")
                .font(.novaCallout).foregroundStyle(NovaColor.body)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(SimulatorViewModel.suggestions, id: \.self) { chip in
                        Button(chip) { viewModel.useSuggestion(chip, model: model) }
                            .buttonStyle(NovaChipStyle())
                    }
                }
            }
            HStack(spacing: Spacing.xs) {
                TextField("What if I…", text: $viewModel.question, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($questionFocused)
                    .submitLabel(.send)
                    .onSubmit { Task { await viewModel.ask(model: model) } }
                    .novaField()
                Button {
                    questionFocused = false
                    Task { await viewModel.ask(model: model) }
                } label: {
                    Group {
                        if viewModel.isThinking { ProgressView().tint(NovaColor.onAction) } else { Image(systemName: "arrow.up") }
                    }
                    .font(.headline)
                    .foregroundStyle(NovaColor.onAction)
                    .frame(width: 48, height: 48)
                    .background(NovaColor.action, in: Circle())
                }
                .disabled(viewModel.question.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isThinking)
                .accessibilityLabel("Ask")
            }
            if !model.isPro {
                let left = max(0, SimulatorViewModel.freeQuestionLimit - viewModel.questionsUsed)
                Text(left > 0 ? "\(left) free question left. Pro gives you unlimited questions." : "You've used your free question. Upgrade to Pro for unlimited questions.")
                    .font(.novaCaption).foregroundStyle(NovaColor.muted)
            }
        }
    }
}

/// "What if I quit my job?" runway slider.
private struct RunwaySliderCard: View {
    @Bindable var viewModel: SimulatorViewModel
    let summary: FinancialSummary

    var body: some View {
        let months = viewModel.runwayMonths(summary: summary)
        NovaCard {
            SectionHeader(title: "What if I quit my job?", systemImage: "briefcase.fill")
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", months)).font(.novaHero).foregroundStyle(NovaColor.heading).monospacedDigit()
                Text("months of runway").font(.novaBody).foregroundStyle(NovaColor.body)
            }
            .accessibilityElement(children: .combine)
            Text("Cut monthly spending by \(viewModel.spendingCut.percent)")
                .font(.novaCallout).foregroundStyle(NovaColor.heading)
            Slider(value: $viewModel.spendingCut, in: 0...0.5, step: 0.05) {
                Text("Spending cut")
            } minimumValueLabel: {
                Text("0%").font(.novaCaption)
            } maximumValueLabel: {
                Text("50%").font(.novaCaption)
            }
            .accessibilityValue(viewModel.spendingCut.percent)
            Text("\(summary.savings.gbpWhole) saved ÷ \((summary.avgMonthly * (1 - viewModel.spendingCut)).gbpWhole) a month")
                .font(.novaCaption).foregroundStyle(NovaColor.muted)
        }
    }
}

/// One what-if answer. Ported from ScenarioCard.tsx.
private struct ScenarioCard: View {
    let result: WhatIfResult
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        NovaCard {
            Button(action: toggle) {
                HStack(alignment: .top) {
                    Text(result.question).font(.novaHeadline).foregroundStyle(NovaColor.brandText).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(NovaColor.muted)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapse" : "Expand")

            Text(result.outcome).font(.novaBody).foregroundStyle(NovaColor.heading)
                .fixedSize(horizontal: false, vertical: true)

            if !result.period.isEmpty {
                Text("\(result.isPositive ? "+" : "−")\(result.amount.magnitude.gbpWhole) a \(result.period)")
                    .font(.novaHeadline)
                    .foregroundStyle(result.isPositive ? NovaColor.success : NovaColor.error)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(result.isPositive ? NovaColor.successTint : NovaColor.errorTint, in: Capsule())
            }

            if isExpanded {
                HStack(spacing: Spacing.sm) {
                    comparison(result.beforeLabel, result.beforeValue, NovaColor.tonal)
                    Image(systemName: "arrow.right").foregroundStyle(NovaColor.muted).accessibilityHidden(true)
                    comparison(result.afterLabel, result.afterValue, NovaColor.lilac)
                }
                Text(result.details).font(.novaCallout).foregroundStyle(NovaColor.body)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Confidence \(result.confidence)%").font(.novaCaption).foregroundStyle(NovaColor.muted)
            }
        }
    }

    private func comparison(_ label: String, _ value: Double, _ background: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.novaCaption).foregroundStyle(NovaColor.body)
            Text(value.gbpWhole).font(.novaHeadline).foregroundStyle(NovaColor.heading).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct TipsCard: View {
    let tips: [String]

    var body: some View {
        NovaCard {
            SectionHeader(title: "Budget tips", systemImage: "lightbulb.fill")
            if tips.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            }
            ForEach(tips, id: \.self) { tip in
                Label(tip, systemImage: "circle.fill").labelStyle(BulletLabelStyle())
            }
        }
    }
}
