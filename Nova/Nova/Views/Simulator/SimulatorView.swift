import Charts
import SwiftUI

/// Scenario simulator: runway slider, what-if questions and budget tips.
struct SimulatorView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = SimulatorViewModel()
    @State private var sandbox = SandboxViewModel()
    @FocusState private var questionFocused: Bool

    var body: some View {
        NavigationStack {
            NovaScreen {
                if !model.hasData {
                    NoDataView()
                } else {
                    if model.isTeen { SandboxCard(viewModel: sandbox) }
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
            #if DEBUG
            // Launch with `-NovaAsk "What if I cycle to work?"` to ask a question on open (for demos and screenshots).
            // Separate several questions with "||" to ask them one after another.
            .task {
                if let questions = UserDefaults.standard.string(forKey: "NovaAsk"), viewModel.results.isEmpty, model.hasData {
                    for question in questions.components(separatedBy: "||") {
                        viewModel.question = question
                        await viewModel.ask(model: model)
                    }
                }
            }
            #endif
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

/// One what-if answer: a generated illustration, the headline effect, a 12-month
/// savings projection, a breakdown and the details. Ported from ScenarioCard.tsx.
private struct ScenarioCard: View {
    let result: WhatIfResult
    let isExpanded: Bool
    let toggle: () -> Void

    private var tint: Color { result.isPositive ? NovaColor.success : NovaColor.error }

    var body: some View {
        NovaCard {
            if let info = result.infographic {
                WhatIfIllustration(theme: info.theme, url: info.illustrationURL, icon: info.icon)
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: info.icon)
                            .font(.headline)
                            .foregroundStyle(NovaColor.onAction)
                            .frame(width: 40, height: 40)
                            .background(NovaColor.action, in: Circle())
                            .overlay(Circle().strokeBorder(NovaColor.card, lineWidth: 2))
                            .padding(Spacing.sm)
                            .accessibilityHidden(true)
                    }
            }

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

            HStack(spacing: Spacing.xs) {
                if !result.period.isEmpty {
                    Label("\(result.isPositive ? "+" : "−")\(result.amount.magnitude.gbpWhole) a \(result.period)",
                          systemImage: result.isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.novaHeadline)
                        .foregroundStyle(tint)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(result.isPositive ? NovaColor.successTint : NovaColor.errorTint, in: Capsule())
                }
                ConfidencePill(confidence: result.confidence)
            }

            if let info = result.infographic, !info.equivalent.isEmpty {
                Label(info.equivalent, systemImage: "sparkles")
                    .font(.novaCallout)
                    .foregroundStyle(NovaColor.heading)
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NovaColor.lilac, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }

            if isExpanded {
                if let info = result.infographic, info.baseline.count > 1 {
                    ProjectionChart(info: info)
                    if !info.breakdown.isEmpty { BreakdownList(items: info.breakdown) }
                }
                HStack(spacing: Spacing.sm) {
                    comparison(result.beforeLabel, result.beforeValue, NovaColor.tonal)
                    Image(systemName: "arrow.right").foregroundStyle(NovaColor.muted).accessibilityHidden(true)
                    comparison(result.afterLabel, result.afterValue, NovaColor.lilac)
                }
                Text(result.details).font(.novaCallout).foregroundStyle(NovaColor.body)
                    .fixedSize(horizontal: false, vertical: true)
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

private struct ConfidencePill: View {
    let confidence: Int

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Gauge(value: Double(confidence), in: 0...100) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(NovaColor.action)
                .scaleEffect(0.42)
                .frame(width: 22, height: 22)
            Text("\(confidence)% sure").font(.novaCaption.weight(.semibold)).foregroundStyle(NovaColor.body)
        }
        .padding(.trailing, Spacing.xs)
        .padding(.vertical, 2)
        .background(NovaColor.tonal, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confidence \(confidence) percent")
    }
}

/// Savings balance over the next 12 months, with and without the change.
private struct ProjectionChart: View {
    let info: WhatIfInfographic
    @State private var selectedMonth: Int?

    private let withLabel = "With the change"
    private let withoutLabel = "Without"

    private struct Point: Identifiable {
        let month: Int
        let value: Double
        let series: String
        var id: String { "\(series)-\(month)" }
    }

    private var points: [Point] {
        info.baseline.enumerated().map { Point(month: $0.offset, value: $0.element, series: withoutLabel) } +
        info.scenario.enumerated().map { Point(month: $0.offset, value: $0.element, series: withLabel) }
    }

    var body: some View {
        let diff = info.yearDifference
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Savings in 12 months").overline()
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text((info.scenario.last ?? 0).gbpWhole).font(.novaTitle).foregroundStyle(NovaColor.heading).monospacedDigit()
                Text("\(diff >= 0 ? "+" : "−")\(diff.magnitude.gbpWhole) vs not changing")
                    .font(.novaCallout.weight(.semibold))
                    .foregroundStyle(diff >= 0 ? NovaColor.success : NovaColor.error)
            }
            if info.oneOffCost > 0 {
                Text("Includes \(info.oneOffCost.gbpWhole) to get started")
                    .font(.novaCaption).foregroundStyle(NovaColor.muted)
            }

            Chart {
                ForEach(points.filter { $0.series == withLabel }) { p in
                    AreaMark(x: .value("Month", p.month), y: .value("Savings", p.value))
                        .foregroundStyle(LinearGradient(colors: [NovaColor.action.opacity(0.18), NovaColor.action.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                }
                ForEach(points) { p in
                    LineMark(x: .value("Month", p.month), y: .value("Savings", p.value), series: .value("Series", p.series))
                        .foregroundStyle(by: .value("Series", p.series))
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: p.series == withoutLabel ? [5, 4] : []))
                        .interpolationMethod(.monotone)
                }
                if let last = info.scenario.indices.last {
                    PointMark(x: .value("Month", last), y: .value("Savings", info.scenario[last]))
                        .foregroundStyle(NovaColor.action)
                        .symbolSize(60)
                }
                if let month = selectedMonth, info.baseline.indices.contains(month), info.scenario.indices.contains(month) {
                    RuleMark(x: .value("Month", month))
                        .foregroundStyle(NovaColor.hairline)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(month == 0 ? "Now" : "Month \(month)").font(.novaMicro).foregroundStyle(NovaColor.muted)
                                Text("With: \(info.scenario[month].gbpWhole)").font(.novaCaption.weight(.semibold)).foregroundStyle(NovaColor.heading)
                                Text("Without: \(info.baseline[month].gbpWhole)").font(.novaCaption).foregroundStyle(NovaColor.body)
                            }
                            .padding(Spacing.xs)
                            .background(NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.control))
                            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(NovaColor.hairline))
                        }
                }
            }
            .chartForegroundStyleScale([withLabel: NovaColor.action, withoutLabel: NovaColor.chartGrey])
            .chartLegend(position: .bottom, alignment: .leading)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXScale(domain: 0...12)
            .chartXAxis {
                AxisMarks(values: [0, 3, 6, 9, 12]) { value in
                    AxisGridLine().foregroundStyle(NovaColor.hairline.opacity(0.5))
                    AxisValueLabel {
                        if let m = value.as(Int.self) { Text(m == 0 ? "Now" : "\(m)m").font(.novaMicro).foregroundStyle(NovaColor.muted) }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(NovaColor.hairline.opacity(0.5))
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text(Self.short(v)).font(.novaMicro).foregroundStyle(NovaColor.muted) }
                    }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .frame(height: 180)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Savings projection")
            .accessibilityValue("In 12 months: \((info.scenario.last ?? 0).gbpWhole) with the change, \((info.baseline.last ?? 0).gbpWhole) without.")
        }
        .padding(Spacing.sm)
        .background(NovaColor.page, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    static func short(_ value: Double) -> String {
        value.magnitude >= 1000 ? "£\(String(format: "%.1f", value / 1000))k" : value.gbpWhole
    }
}

/// What makes up the monthly figure, as simple signed bars.
private struct BreakdownList: View {
    let items: [WhatIfInfographic.BreakdownItem]

    var body: some View {
        let maxValue = max(1, items.map { $0.amount.magnitude }.max() ?? 1)
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Where it comes from").overline()
            ForEach(items, id: \.self) { item in
                let saves = item.amount >= 0
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.label).font(.novaCallout).foregroundStyle(NovaColor.heading)
                        Spacer()
                        Text("\(saves ? "+" : "−")\(item.amount.magnitude.gbpWhole)/mo")
                            .font(.novaCallout.weight(.semibold)).foregroundStyle(NovaColor.heading).monospacedDigit()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(NovaColor.track)
                            Capsule().fill(saves ? NovaColor.success : NovaColor.error)
                                .frame(width: max(6, geo.size.width * item.amount.magnitude / maxValue))
                        }
                    }
                    .frame(height: 6)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.label), \(saves ? "saves" : "costs") \(item.amount.magnitude.gbpWhole) a month")
            }
        }
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
