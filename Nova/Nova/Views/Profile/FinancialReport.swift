import Charts
import PDFKit
import SwiftUI

// MARK: - Health score

/// A simple 0–100 financial health score built from four parts the user can act on.
struct FinancialHealth {
    struct Part: Identifiable {
        let name: String
        let score: Double
        let maxScore: Double
        let detail: String
        var id: String { name }
        var fraction: Double { maxScore > 0 ? score / maxScore : 0 }
    }

    let parts: [Part]
    var score: Int { Int(parts.reduce(0) { $0 + $1.score }.rounded()) }

    var rating: String {
        switch score {
        case 80...: "Excellent"
        case 65..<80: "Good"
        case 45..<65: "Fair"
        default: "Needs attention"
        }
    }

    init(summary s: FinancialSummary, trend: SpendingTrend? = nil) {
        let trend = trend ?? s.spendingTrend
        let savingsPoints = min(1, s.savingsRate / 20) * 30
        let runwayPoints = min(1, s.runwayMonths / 6) * 30
        let balance = s.avgMonthly > 0 ? s.monthlyIncome / s.avgMonthly : 1
        let balancePoints = min(1, max(0, balance)) * 20
        let trendPoints: Double = switch trend {
        case .decreasing: 20
        case .stable: 15
        case .increasing: 6
        }
        let trendText: String = switch trend {
        case .decreasing: "Spending is falling"
        case .stable: "Spending is steady"
        case .increasing: "Spending is rising"
        }
        parts = [
            Part(name: "Savings rate", score: savingsPoints, maxScore: 30,
                 detail: "\(Int(s.savingsRate))% of income saved (aim for 20%)"),
            Part(name: "Safety net", score: runwayPoints, maxScore: 30,
                 detail: "\(String(format: "%.1f", s.runwayMonths)) months of spending saved (aim for 6)"),
            Part(name: "Living within means", score: balancePoints, maxScore: 20,
                 detail: s.monthlyIncome >= s.avgMonthly
                    ? "Income covers spending by \((s.monthlyIncome - s.avgMonthly).gbpWhole) a month"
                    : "Spending is \((s.avgMonthly - s.monthlyIncome).gbpWhole) a month over income"),
            Part(name: "Spending trend", score: trendPoints, maxScore: 20, detail: trendText),
        ]
    }
}

// MARK: - Report page (A4)

/// One A4 page summarising the user's financial health. Rendered to PDF with `ImageRenderer`.
struct FinancialReportPage: View {
    static let size = CGSize(width: 595, height: 842) // A4 in points

    let name: String
    let summary: FinancialSummary
    let transactions: [Transaction]
    let generatedAt: Date

    private var health: FinancialHealth { FinancialHealth(summary: summary, trend: completeTrend) }

    /// Monthly totals without partly-covered months at either end of the data
    /// (a part month would look like a sudden drop in spending and income).
    private var completeMonths: [MonthlySnapshot] {
        var months = summary.monthlySnapshots
        let calendar = Calendar.current
        if let last = months.last, let lastDate = transactions.map(\.date).max() {
            let daysInMonth = calendar.range(of: .day, in: .month, for: last.month)?.count ?? 30
            if calendar.isDate(last.month, equalTo: lastDate, toGranularity: .month),
               calendar.component(.day, from: lastDate) < daysInMonth - 2 {
                months.removeLast()
            }
        }
        if let first = months.first, let firstDate = transactions.map(\.date).min(),
           calendar.isDate(first.month, equalTo: firstDate, toGranularity: .month),
           calendar.component(.day, from: firstDate) > 3 {
            months.removeFirst()
        }
        return months
    }

    /// Same rule as `FinancialSummary`, applied to complete months only.
    private var completeTrend: SpendingTrend {
        let amounts = completeMonths.map(\.totalSpent)
        guard amounts.count >= 3 else { return .stable }
        let recent = amounts.suffix(2).reduce(0, +) / 2
        let older = amounts.dropLast(2).reduce(0, +) / Double(amounts.count - 2)
        if recent > older * 1.1 { return .increasing }
        if recent < older * 0.9 { return .decreasing }
        return .stable
    }
    private let spendColor = NovaColor.chartAubergine
    private let incomeColor = NovaColor.chartBroccoli

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    scoreBlock.frame(width: 250)
                    kpiGrid
                }
                HStack(alignment: .top, spacing: 14) {
                    panel("Income vs spending by month") { monthlyChart }
                        .frame(width: 330)
                    panel("Spending by season") { seasonalChart }
                }
                HStack(alignment: .top, spacing: 14) {
                    panel("Where your money goes (per month)") { categoryBars }
                        .frame(width: 330)
                    panel("Key insights") { insightsList }
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    // Header band
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Financial health report").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                Text("\(name) · \(periodText)").font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    NatWestMark(size: 22)
                    Text("Nova").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                }
                Text("Generated \(generatedAt.formatted(.dateTime.day().month(.wide).year()))")
                    .font(.system(size: 8.5)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(NovaColor.regal)
    }

    private var periodText: String {
        guard let first = transactions.map(\.date).min(), let last = transactions.map(\.date).max() else { return "No data" }
        let f = Date.FormatStyle.dateTime.month(.abbreviated).year()
        return "\(first.formatted(f)) – \(last.formatted(f)) · \(transactions.count) transactions"
    }

    // Score ring + parts
    private var scoreBlock: some View {
        let h = health
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(NovaColor.track, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: Double(h.score) / 100)
                        .stroke(NovaColor.action, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(h.score)").font(.system(size: 26, weight: .bold)).foregroundStyle(NovaColor.heading)
                        Text("of 100").font(.system(size: 8)).foregroundStyle(NovaColor.muted)
                    }
                }
                .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Health score").font(.system(size: 9, weight: .semibold)).textCase(.uppercase).foregroundStyle(NovaColor.muted)
                    Text(h.rating).font(.system(size: 18, weight: .bold)).foregroundStyle(NovaColor.brandText)
                        .lineLimit(2).minimumScaleFactor(0.75).fixedSize(horizontal: false, vertical: true)
                    Text("Based on saving, safety net, balance and trend.").font(.system(size: 8.5)).foregroundStyle(NovaColor.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(h.parts) { part in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(part.name).font(.system(size: 9, weight: .semibold)).foregroundStyle(NovaColor.heading)
                            Spacer()
                            Text("\(Int(part.score.rounded()))/\(Int(part.maxScore))").font(.system(size: 9)).foregroundStyle(NovaColor.body).monospacedDigit()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(NovaColor.track)
                                Capsule().fill(NovaColor.action).frame(width: max(4, geo.size.width * part.fraction))
                            }
                        }
                        .frame(height: 5)
                        Text(part.detail).font(.system(size: 7.5)).foregroundStyle(NovaColor.muted)
                    }
                }
            }
        }
        .padding(12)
        .background(NovaColor.lilac, in: RoundedRectangle(cornerRadius: 10))
    }

    // Key numbers
    private var kpiGrid: some View {
        let s = summary
        let tiles: [(String, String, String)] = [
            ("Monthly income", s.monthlyIncome.gbpWhole, "average"),
            ("Monthly spending", s.avgMonthly.gbpWhole, "average"),
            ("Saved each month", (s.monthlyIncome - s.avgMonthly).gbpWhole, "\(Int(s.savingsRate))% savings rate"),
            ("Savings balance", s.savings.gbpWhole, "Flexible Saver"),
            ("Runway", String(format: "%.1f months", s.runwayMonths), "if income stopped"),
            ("Daily spending", s.avgDaily.gbp, "average"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(tiles, id: \.0) { tile in
                VStack(alignment: .leading, spacing: 3) {
                    Text(tile.0).font(.system(size: 8.5, weight: .semibold)).textCase(.uppercase).foregroundStyle(NovaColor.muted)
                    Text(tile.1).font(.system(size: 17, weight: .bold)).foregroundStyle(NovaColor.heading).monospacedDigit()
                        .minimumScaleFactor(0.7).lineLimit(1)
                    Text(tile.2).font(.system(size: 8)).foregroundStyle(NovaColor.body)
                }
                .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                .padding(10)
                .background(NovaColor.page, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // Monthly chart: spending bars, income line
    private var recentMonths: [MonthlySnapshot] { Array(completeMonths.suffix(12)) }

    private var monthlyChart: some View {
        Chart {
            ForEach(recentMonths) { m in
                BarMark(x: .value("Month", m.month, unit: .month), y: .value("£", m.totalSpent), width: .ratio(0.6))
                    .foregroundStyle(by: .value("Series", "Spending"))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3))
            }
            ForEach(recentMonths) { m in
                LineMark(x: .value("Month", m.month, unit: .month), y: .value("£", m.totalIncome))
                    .foregroundStyle(by: .value("Series", "Income"))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .symbol { Circle().fill(incomeColor).frame(width: 4, height: 4) }
            }
        }
        .chartForegroundStyleScale(["Spending": spendColor, "Income": incomeColor])
        .chartLegend(position: .top, alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                legendItem("Spending", color: spendColor, dashed: false)
                legendItem("Income", color: incomeColor, dashed: true)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true).font(.system(size: 7))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(NovaColor.hairline)
                AxisValueLabel { if let v = value.as(Double.self) { Text(Self.short(v)).font(.system(size: 7)) } }
            }
        }
        .frame(height: 150)
    }

    // Seasonal bars (one hue: magnitude)
    private var seasonalChart: some View {
        let seasons: [(String, Double)] = [("Winter", summary.seasonal.winter), ("Spring", summary.seasonal.spring),
                                           ("Summer", summary.seasonal.summer), ("Autumn", summary.seasonal.autumn)]
        let peak = seasons.max { $0.1 < $1.1 }?.0
        return VStack(alignment: .leading, spacing: 4) {
            Chart(seasons, id: \.0) { season in
                BarMark(x: .value("Season", season.0), y: .value("£", season.1), width: .ratio(0.55))
                    .foregroundStyle(season.0 == peak ? spendColor : spendColor.opacity(0.45))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3))
                    .annotation(position: .top, spacing: 2) {
                        Text(Self.short(season.1)).font(.system(size: 7, weight: .semibold)).foregroundStyle(NovaColor.heading)
                    }
            }
            .chartYAxis(.hidden)
            .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 7.5)) } }
            .frame(height: 132)
            if let peak { Text("Average monthly spend by season. You spend most in \(peak.lowercased()).").font(.system(size: 7.5)).foregroundStyle(NovaColor.muted) }
        }
    }

    // Category bars (one hue, ranked)
    private var categoryRows: [CategoryTotal] {
        summary.topCategories.filter { $0.category != .transfer && $0.category != .income }.prefix(6).map { $0 }
    }

    private var categoryBars: some View {
        let months = max(1, summary.dataRangeMonths)
        let top = categoryRows.first?.amount ?? 1
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(categoryRows) { row in
                HStack(spacing: 8) {
                    Label(row.category.rawValue, systemImage: row.category.symbol)
                        .font(.system(size: 8.5)).foregroundStyle(NovaColor.heading)
                        .frame(width: 92, alignment: .leading)
                    GeometryReader { geo in
                        Capsule().fill(spendColor).frame(width: max(4, geo.size.width * row.amount / top))
                    }
                    .frame(height: 7)
                    Text("\((row.amount / months).gbpWhole) · \(row.share.percent)")
                        .font(.system(size: 8, weight: .semibold)).foregroundStyle(NovaColor.heading).monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
    }

    // Insights
    private var insights: [String] {
        let s = summary
        let months = max(1, s.dataRangeMonths)
        var list: [String] = []
        if let top = s.topCategories.first(where: { ![.rent, .utilities, .transfer, .income].contains($0.category) }) {
            let monthly = top.amount / months
            list.append("Your biggest everyday spend is \(top.category.rawValue.lowercased()) at \(monthly.gbpWhole) a month. Cutting it by a quarter would save \((monthly * 3).gbpWhole) a year.")
        }
        if s.monthlyIncome >= s.avgMonthly {
            list.append("You keep \((s.monthlyIncome - s.avgMonthly).gbpWhole) a month after spending. A payday standing order makes that saving automatic.")
        } else {
            list.append("You're spending \((s.avgMonthly - s.monthlyIncome).gbpWhole) a month more than you earn, which draws down your savings.")
        }
        list.append(s.runwayMonths >= 6
            ? "Your savings would cover \(String(format: "%.1f", s.runwayMonths)) months of spending, a healthy safety net."
            : "Your savings cover \(String(format: "%.1f", s.runwayMonths)) months of spending. Building to 6 months means saving \((max(0, s.avgMonthly * 6 - s.savings)).gbpWhole) more.")
        if let best = recentMonths.min(by: { $0.totalSpent < $1.totalSpent }),
           let worst = recentMonths.max(by: { $0.totalSpent < $1.totalSpent }), best.month != worst.month {
            list.append("Your lowest-spending month was \(best.month.formatted(.dateTime.month(.wide))) (\(best.totalSpent.gbpWhole)); the highest was \(worst.month.formatted(.dateTime.month(.wide))) (\(worst.totalSpent.gbpWhole)).")
        }
        return list
    }

    private var insightsList: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(insights.enumerated()), id: \.offset) { item in
                HStack(alignment: .top, spacing: 6) {
                    Circle().fill(NovaColor.action).frame(width: 5, height: 5).padding(.top, 4)
                    Text(item.element).font(.system(size: 8.5)).foregroundStyle(NovaColor.heading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Figures are averages from your imported transactions. This summary is for information only and isn't financial advice.")
                .font(.system(size: 7)).foregroundStyle(NovaColor.muted)
            Spacer()
            Text("Nova by NatWest").font(.system(size: 7, weight: .semibold)).foregroundStyle(NovaColor.brandText)
        }
        .padding(.top, 8)
        .overlay(alignment: .top) { Rectangle().fill(NovaColor.hairline).frame(height: 0.5) }
    }

    private func legendItem(_ title: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            if dashed {
                Path { p in p.move(to: CGPoint(x: 0, y: 3)); p.addLine(to: CGPoint(x: 14, y: 3)) }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: 14, height: 6)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            }
            Text(title).font(.system(size: 8)).foregroundStyle(NovaColor.body)
        }
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 10.5, weight: .bold)).foregroundStyle(NovaColor.brandText)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(NovaColor.hairline))
    }

    static func short(_ value: Double) -> String {
        value.magnitude >= 1000 ? "£\(String(format: "%.1f", value / 1000))k" : value.gbpWhole
    }
}

// MARK: - PDF export

enum FinancialReportExporter {
    /// Renders the report page to a one-page PDF in the temporary folder and returns its URL.
    @MainActor
    static func makePDF(name: String, summary: FinancialSummary, transactions: [Transaction]) throws -> URL {
        let page = FinancialReportPage(name: name, summary: summary, transactions: transactions, generatedAt: .now)
        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(FinancialReportPage.size)

        let date = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Nova Financial Health \(date).pdf")
        var box = CGRect(origin: .zero, size: FinancialReportPage.size)
        var failed = false
        renderer.render { _, draw in
            guard let context = CGContext(url as CFURL, mediaBox: &box, [
                kCGPDFContextTitle: "Financial health report" as CFString,
                kCGPDFContextCreator: "Nova" as CFString,
            ] as CFDictionary) else { failed = true; return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        if failed { throw ServiceError.network("Couldn't create the PDF. Please try again.") }
        return url
    }
}

/// Preview of the exported PDF with a share button.
struct FinancialReportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let url {
                    PDFPreview(url: url).ignoresSafeArea(edges: .bottom)
                } else if let error {
                    ContentUnavailableView("Couldn't create report", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ProgressView("Building your report…")
                }
            }
            .background(NovaColor.page)
            .navigationTitle("Financial health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if let url {
                        ShareLink(item: url, preview: SharePreview("Financial health report", image: Image(systemName: "doc.richtext"))) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task {
                do {
                    url = try FinancialReportExporter.makePDF(name: model.user?.name ?? "Your", summary: model.summary,
                                                              transactions: model.transactions)
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

private struct PDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.backgroundColor = UIColor(NovaColor.page)
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
    }
}
