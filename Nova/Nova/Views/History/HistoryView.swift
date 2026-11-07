import Charts
import SwiftUI

/// Spending history and patterns: period toggle, week comparison, category donut,
/// unusual spikes and the transaction list.
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = HistoryViewModel()
    @State private var insights = InsightsViewModel()
    @State private var alerts: [SpendingAlert] = []

    var body: some View {
        NavigationStack {
            NovaScreen {
                if !model.hasData {
                    NoDataView()
                } else {
                    PeriodPicker(viewModel: viewModel)
                    if viewModel.period != .week && !model.isPro {
                        ProLockedCard(feature: .fullHistory)
                    } else {
                        content
                    }
                }
            }
            .navigationTitle("History")
            .profileToolbar()
            .searchable(text: $viewModel.searchText, prompt: "Search transactions")
            .task(id: model.dataVersion) {
                await insights.load(model: model)
                alerts = (try? await model.services.insights.alerts(from: model.transactions)) ?? []
            }
        }
    }

    @ViewBuilder private var content: some View {
        let totals = viewModel.categoryTotals(in: model.transactions)
        NovaCard {
            Text("Spent this \(viewModel.period.rawValue.lowercased())").overline()
            Text(viewModel.totalSpent(in: model.transactions).gbp)
                .font(.novaHero)
                .foregroundStyle(NovaColor.heading)
                .monospacedDigit()
        }
        if viewModel.period == .week {
            WeekOverWeekCard(rows: insights.weekComparison)
        }
        CategoryDonutCard(totals: totals)
        ForEach(alerts.filter { $0.kind == .spike }) { AlertCard(alert: $0) }
        TransactionList(groups: viewModel.groupedByDay(model.transactions))
    }
}

private struct PeriodPicker: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: HistoryViewModel

    var body: some View {
        Picker("Period", selection: $viewModel.period) {
            ForEach(HistoryViewModel.Period.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Category breakdown donut. Ported from CategoryDonut.tsx.
private struct CategoryDonutCard: View {
    let totals: [CategoryTotal]
    @State private var selectedAmount: Double?

    private var selected: CategoryTotal? {
        guard let selectedAmount else { return nil }
        var running = 0.0
        for total in totals {
            running += total.amount
            if selectedAmount <= running { return total }
        }
        return nil
    }

    var body: some View {
        NovaCard {
            SectionHeader(title: "Where your money went", systemImage: "chart.pie.fill")
            if totals.isEmpty {
                Text("No spending in this period.").font(.novaCallout).foregroundStyle(NovaColor.body)
            } else {
                Chart(totals) { total in
                    SectorMark(
                        angle: .value("Amount", total.amount),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(total.category.color)
                    .opacity(selected == nil || selected?.category == total.category ? 1 : 0.35)
                }
                .chartAngleSelection(value: $selectedAmount)
                .chartBackground { _ in
                    VStack(spacing: 0) {
                        Text(selected?.category.rawValue ?? "Total")
                            .font(.novaCaption).foregroundStyle(NovaColor.body)
                        Text((selected?.amount ?? totals.reduce(0) { $0 + $1.amount }).gbpWhole)
                            .font(.novaTitle).foregroundStyle(NovaColor.heading).monospacedDigit()
                    }
                }
                .frame(height: 220)
                .accessibilityLabel("Spending by category")

                ForEach(totals.prefix(6)) { total in
                    HStack(spacing: Spacing.xs) {
                        Circle().fill(total.category.color).frame(width: 10, height: 10).accessibilityHidden(true)
                        Text(total.category.rawValue).font(.novaCallout).foregroundStyle(NovaColor.heading)
                        Spacer()
                        Text(total.amount.gbp).font(.novaCallout).foregroundStyle(NovaColor.heading).monospacedDigit()
                        Text(total.share.percent).font(.novaCaption).foregroundStyle(NovaColor.body)
                            .frame(minWidth: 40, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct TransactionList: View {
    @Environment(AppModel.self) private var model
    let groups: [(day: Date, items: [Transaction])]

    var body: some View {
        NovaCard {
            SectionHeader(title: "Transactions", systemImage: "list.bullet")
            if groups.isEmpty {
                Text("No matching transactions.").font(.novaCallout).foregroundStyle(NovaColor.body)
            }
            ForEach(groups, id: \.day) { group in
                Text(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide))).overline()
                    .padding(.top, Spacing.xs)
                ForEach(group.items) { transaction in
                    TransactionRow(transaction: transaction)
                        .contextMenu {
                            if transaction.isManual {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    Task { await model.deleteTransaction(transaction.id) }
                                }
                            }
                        }
                }
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: Spacing.sm) {
            CategoryIcon(category: transaction.category, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description).font(.novaBody).foregroundStyle(NovaColor.heading).lineLimit(1)
                Text(transaction.category.rawValue + (transaction.isManual ? " · Added by you" : ""))
                    .font(.novaCaption).foregroundStyle(NovaColor.body)
            }
            Spacer()
            Text(transaction.amount > 0 ? "+" + transaction.amount.gbp : transaction.amount.magnitude.gbp)
                .font(.novaBody.weight(.semibold))
                .foregroundStyle(transaction.amount > 0 ? NovaColor.success : NovaColor.heading)
                .monospacedDigit()
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
