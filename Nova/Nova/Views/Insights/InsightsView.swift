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

/// Seasonal spending comparison. Ported from SeasonalBars.tsx.
private struct SeasonalCard: View {
    let seasonal: SeasonalSpend

    private var rows: [(String, Double, Color)] {
        [("Winter", seasonal.winter, NovaColor.chartBlueberry),
         ("Spring", seasonal.spring, NovaColor.chartBroccoli),
         ("Summer", seasonal.summer, NovaColor.chartYolk),
         ("Autumn", seasonal.autumn, NovaColor.chartTangerine)]
    }

    var body: some View {
        NovaCard {
            SectionHeader(title: "Seasonal spending", systemImage: "leaf.fill")
            Chart(rows, id: \.0) { row in
                BarMark(x: .value("Season", row.0), y: .value("Average per month", row.1))
                    .foregroundStyle(row.2)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text(row.1.gbpWhole).font(.novaMicro).foregroundStyle(NovaColor.body)
                    }
            }
            .chartYAxis(.hidden)
            .frame(height: 180)
            let delta = seasonal.winter - seasonal.summer
            Text(delta >= 0
                 ? "You spend \(delta.gbpWhole) more a month in winter than in summer."
                 : "You spend \((-delta).gbpWhole) more a month in summer than in winter.")
                .font(.novaCallout)
                .foregroundStyle(NovaColor.body)
        }
    }
}

/// Monthly spend with a dashed projection. Ported from SpendTrajectory.tsx.
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

/// Weekly recap with AI accuracy score (Pro). Ported from AccuracyRing / PredictionComparison.
private struct WeeklyRecapCard: View {
    let recap: WeeklyRecap

    var body: some View {
        NovaCard {
            SectionHeader(title: "Weekly recap", systemImage: "checkmark.seal.fill")
            HStack(spacing: Spacing.lg) {
                RingView(progress: recap.accuracy / 100, lineWidth: 10, tint: NovaColor.success) {
                    Text("\(Int(recap.accuracy))%")
                        .font(.novaHeadline)
                        .foregroundStyle(NovaColor.heading)
                }
                .frame(width: 84, height: 84)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Prediction accuracy \(Int(recap.accuracy)) percent")
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Metric(label: "Predicted", value: recap.predictedTotal.gbpWhole)
                    Metric(label: "Actual", value: recap.actualTotal.gbpWhole)
                }
            }
            Text("Highlights").overline()
            ForEach(recap.highlights, id: \.self) { line in
                Label(line, systemImage: "circle.fill")
                    .labelStyle(BulletLabelStyle())
            }
        }
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
