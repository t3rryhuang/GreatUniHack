import Charts
import SwiftUI

/// Long-horizon insights: runway, seasonal spending, trajectory, weekly recap.
struct InsightsView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = InsightsViewModel()

    var body: some View {
        NavigationStack {
            NovaScreen {
                if !model.hasData {
                    NoDataView(title: "No data available", message: "Upload transactions to see your long-term outlook.")
                } else {
                    RunwayCard(summary: model.summary, runway: viewModel.runway)
                    SeasonalCard(seasonal: model.summary.seasonal)
                    TrajectoryCard(points: viewModel.trajectory, trend: model.summary.spendingTrend)
                    if model.isPro {
                        if let recap = viewModel.recap {
                            WeeklyRecapCard(recap: recap)
                        } else {
                            LoadingCard(label: "Building your weekly recap…")
                        }
                    } else {
                        ProLockedCard(feature: .weeklyRecap)
                    }
                    WeekOverWeekCard(rows: viewModel.weekComparison)
                    TopSpendingCard(totals: model.summary.topCategories, months: model.summary.dataRangeMonths)
                }
            }
            .navigationTitle("Insights")
            .profileToolbar()
            .refreshable { await viewModel.load(model: model, force: true) }
            .task(id: model.dataVersion) { await viewModel.load(model: model) }
        }
    }
}

/// "Job quit runway". Ported from RunwayRing.tsx.
private struct RunwayCard: View {
    let summary: FinancialSummary
    let runway: RunwayResult?

    var body: some View {
        let months = runway?.months ?? summary.runwayMonths
        NovaCard {
            SectionHeader(title: "Job quit runway", systemImage: "figure.walk.departure")
            HStack(spacing: Spacing.lg) {
                RingView(progress: months / 12) {
                    VStack(spacing: 0) {
                        Text(String(format: "%.1f", months))
                            .font(.novaTitle)
                            .foregroundStyle(NovaColor.heading)
                            .monospacedDigit()
                        Text("months").font(.novaCaption).foregroundStyle(NovaColor.body)
                    }
                }
                .frame(width: 120, height: 120)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Runway \(String(format: "%.1f", months)) months")
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Metric(label: "Current savings", value: summary.savings.gbpWhole)
                    Metric(label: "Monthly burn", value: summary.avgMonthly.gbpWhole)
                    Metric(label: "Savings rate", value: "\(Int(summary.savingsRate))%")
                }
            }
            if let runway {
                Text(runway.analysis)
                    .font(.novaCallout)
                    .foregroundStyle(NovaColor.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct Metric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.novaCaption).foregroundStyle(NovaColor.body)
            Text(value).font(.novaHeadline).foregroundStyle(NovaColor.heading).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Seasonal spending comparison in soft pastels. Ported from SeasonalBars.tsx.
struct SeasonalCard: View {
    let seasonal: SeasonalSpend

    private struct Season: Identifiable {
        let name: String
        let amount: Double
        let symbol: String
        let fill: Color
        let ink: Color
        let months: ClosedRange<Int>
        var id: String { name }
    }

    private var seasons: [Season] {
        [Season(name: "Winter", amount: seasonal.winter, symbol: "snowflake", fill: NovaColor.pastelBlue, ink: NovaColor.chartBlueberry, months: 12...14),
         Season(name: "Spring", amount: seasonal.spring, symbol: "camera.macro", fill: NovaColor.pastelGreen, ink: NovaColor.chartBroccoli, months: 3...5),
         Season(name: "Summer", amount: seasonal.summer, symbol: "sun.max.fill", fill: NovaColor.pastelYellow, ink: NovaColor.chartYolk, months: 6...8),
         Season(name: "Autumn", amount: seasonal.autumn, symbol: "leaf.fill", fill: NovaColor.pastelPeach, ink: NovaColor.chartTangerine, months: 9...11)]
    }

    private var current: String {
        let month = Calendar.current.component(.month, from: .now)
        return seasons.first { $0.months.contains(month) || $0.months.contains(month + 12) }?.name ?? ""
    }

    var body: some View {
        let list = seasons
        let top = list.max { $0.amount < $1.amount }
        let low = list.min { $0.amount < $1.amount }
        NovaCard {
            SectionHeader(title: "Seasonal spending", systemImage: "leaf.fill")
            if let top, let low {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(top.name) is your priciest season").font(.novaSection).foregroundStyle(NovaColor.heading)
                    Text("About \((top.amount - low.amount).gbpWhole) a month more than \(low.name.lowercased()).")
                        .font(.novaCallout).foregroundStyle(NovaColor.body)
                }
                .accessibilityElement(children: .combine)
            }
            Chart(list) { season in
                BarMark(x: .value("Season", season.name), y: .value("Average per month", season.amount), width: .ratio(0.62))
                    .foregroundStyle(season.fill)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10, style: .continuous))
                    .annotation(position: .top, spacing: 6) {
                        Text(season.amount.gbpWhole)
                            .font(.novaCaption.weight(.semibold))
                            .foregroundStyle(season.ink)
                    }
                    .accessibilityLabel(season.name + (season.name == current ? ", this season" : ""))
                    .accessibilityValue("\(season.amount.gbpWhole) a month on average")
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let name = value.as(String.self), let season = list.first(where: { $0.name == name }) {
                            VStack(spacing: 2) {
                                Image(systemName: season.symbol).foregroundStyle(season.ink)
                                Text(name).font(.novaCaption.weight(name == current ? .semibold : .regular))
                                    .foregroundStyle(name == current ? NovaColor.heading : NovaColor.body)
                            }
                        }
                    }
                }
            }
            .frame(height: 200)
            .accessibilityLabel("Average monthly spending by season")
            HStack(spacing: Spacing.xs) {
                ForEach(list) { season in
                    if season.name == current {
                        Label("Now: \(season.name.lowercased())", systemImage: season.symbol)
                            .font(.novaCaption.weight(.semibold))
                            .foregroundStyle(season.ink)
                            .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xxs)
                            .background(season.fill, in: Capsule())
                    }
                }
                Spacer()
                Text("Average per month").font(.novaCaption).foregroundStyle(NovaColor.muted)
            }
        }
    }
}

private struct TrajectoryCard: View {
    let points: [InsightsViewModel.TrajectoryPoint]
    let trend: SpendingTrend

    var body: some View {
        NovaCard {
            SectionHeader(title: "Spending trajectory", systemImage: "chart.line.uptrend.xyaxis") {
                Text(trend.rawValue.capitalized)
                    .font(.novaCaption.weight(.semibold))
                    .foregroundStyle(trend == .increasing ? NovaColor.error : NovaColor.success)
            }
            Chart(points) { point in
                LineMark(x: .value("Month", point.month, unit: .month), y: .value("Spend", point.amount))
                    .foregroundStyle(by: .value("Series", point.isProjection ? "Projected" : "Actual"))
                    .lineStyle(StrokeStyle(lineWidth: 3, dash: point.isProjection ? [6, 4] : []))
                    .interpolationMethod(.catmullRom)
                if !point.isProjection {
                    PointMark(x: .value("Month", point.month, unit: .month), y: .value("Spend", point.amount))
                        .foregroundStyle(NovaColor.action)
                        .symbolSize(30)
                }
            }
            .chartForegroundStyleScale(["Actual": NovaColor.action, "Projected": NovaColor.chartAubergine])
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { if let v = value.as(Double.self) { Text(v.gbpWhole) } }
                }
            }
            .frame(height: 200)
        }
    }
}

/// Weekly recap: how close last week's predictions were, in soft pastels.
/// Ported from AccuracyRing / PredictionComparison.
struct WeeklyRecapCard: View {
    let recap: WeeklyRecap

    var body: some View {
        let difference = recap.actualTotal - recap.predictedTotal
        let scale = max(recap.predictedTotal, recap.actualTotal, 1)
        NovaCard {
            SectionHeader(title: "Weekly recap", systemImage: "checkmark.seal.fill")
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle().fill(NovaColor.pastelGreen)
                    RingView(progress: recap.accuracy / 100, lineWidth: 9, tint: NovaColor.success) {
                        VStack(spacing: 0) {
                            Text("\(Int(recap.accuracy))%").font(.novaSection).foregroundStyle(NovaColor.heading).monospacedDigit()
                            Text("accurate").font(.novaMicro).foregroundStyle(NovaColor.body)
                        }
                    }
                    .padding(8)
                }
                .frame(width: 104, height: 104)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Prediction accuracy")
                .accessibilityValue("\(Int(recap.accuracy)) percent")

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(Int(recap.accuracy) >= 80 ? "Nova knew your week well" : "A less predictable week")
                        .font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    Text(difference <= 0
                         ? "You spent \((-difference).gbpWhole) less than predicted."
                         : "You spent \(difference.gbpWhole) more than predicted.")
                        .font(.novaCallout)
                        .foregroundStyle(NovaColor.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: Spacing.xs) {
                comparisonBar("Predicted", recap.predictedTotal, of: scale, fill: NovaColor.pastelLilac, ink: NovaColor.chartChampion)
                comparisonBar("Actual", recap.actualTotal, of: scale, fill: NovaColor.pastelBlue, ink: NovaColor.chartBlueberry)
            }
            .padding(Spacing.sm)
            .background(NovaColor.tonal, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

            if let top = recap.topCategory {
                Label("Biggest spend: \(top.rawValue.lowercased())", systemImage: top.symbol)
                    .font(.novaCaption.weight(.semibold))
                    .foregroundStyle(top.color)
                    .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xxs)
                    .background(top.color.opacity(0.14), in: Capsule())
            }

            if !recap.highlights.isEmpty {
                Text("Highlights").overline()
                ForEach(Array(recap.highlights.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: ["sparkles", "chart.line.uptrend.xyaxis", "lightbulb.fill", "star.fill"][index % 4])
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(NovaColor.chartChampion)
                            .frame(width: 32, height: 32)
                            .background(NovaColor.pastelLilac, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                            .accessibilityHidden(true)
                        Text(line).font(.novaCallout).foregroundStyle(NovaColor.body)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func comparisonBar(_ label: String, _ value: Double, of scale: Double, fill: Color, ink: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(label).font(.novaCaption).foregroundStyle(NovaColor.body).frame(width: 70, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(NovaColor.card)
                    Capsule().fill(fill).frame(width: max(18, proxy.size.width * value / scale))
                }
            }
            .frame(height: 18)
            Text(value.gbpWhole).font(.novaCallout.weight(.semibold)).foregroundStyle(ink).monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value.gbpWhole)
    }
}

struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Circle().fill(NovaColor.action).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] }
            configuration.title.font(.novaCallout).foregroundStyle(NovaColor.body)
        }
    }
}

/// This week vs last week. Ported from ComparisonChart.tsx.
struct WeekOverWeekCard: View {
    let rows: [InsightsViewModel.WeekComparison]

    var body: some View {
        NovaCard {
            SectionHeader(title: "This week vs last week", systemImage: "arrow.left.arrow.right")
            if rows.isEmpty {
                Text("Not enough data for a comparison yet.").font(.novaCallout).foregroundStyle(NovaColor.body)
            } else {
                Chart {
                    ForEach(rows) { row in
                        BarMark(x: .value("Amount", row.lastWeek), y: .value("Category", row.category.rawValue))
                            .foregroundStyle(by: .value("Week", "Last week"))
                            .position(by: .value("Week", "Last week"))
                        BarMark(x: .value("Amount", row.thisWeek), y: .value("Category", row.category.rawValue))
                            .foregroundStyle(by: .value("Week", "This week"))
                            .position(by: .value("Week", "This week"))
                    }
                }
                .chartForegroundStyleScale(["This week": NovaColor.action, "Last week": NovaColor.track])
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel { if let v = value.as(Double.self) { Text(v.gbpWhole) } }
                    }
                }
                .frame(height: CGFloat(rows.count) * 52 + 40)
            }
        }
    }
}

private struct TopSpendingCard: View {
    let totals: [CategoryTotal]
    let months: Double

    var body: some View {
        NovaCard {
            SectionHeader(title: "Top spending", systemImage: "list.number")
            ForEach(totals.prefix(5)) { total in
                HStack(spacing: Spacing.sm) {
                    CategoryIcon(category: total.category, size: 34)
                    Text(total.category.rawValue).font(.novaBody).foregroundStyle(NovaColor.heading)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text((total.amount / max(1, months)).gbpWhole + "/mo")
                            .font(.novaHeadline).foregroundStyle(NovaColor.heading).monospacedDigit()
                        Text(total.share.percent).font(.novaCaption).foregroundStyle(NovaColor.body)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
