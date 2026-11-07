import Charts
import SwiftUI

/// Teen mode: "What your parent sees". Weekly totals, loan and bill progress and
/// safety alerts only. The teen stays in charge: no individual transactions are shown.
struct ParentPreviewView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = ParentPreviewViewModel()

    var body: some View {
        let first = model.user?.firstName ?? "Your teen"
        NovaScreen {
            NovaNotice(kind: .info, title: "You're in charge",
                       message: "This is a preview of what a parent or carer would see. Individual transactions and shops are never shared.")

            NovaCard {
                SectionHeader(title: "\(first)'s weekly spending", systemImage: "chart.bar.fill")
                let weeks = viewModel.weeklyTotals(model: model)
                if weeks.isEmpty {
                    Text("No spending yet.").font(.novaCallout).foregroundStyle(NovaColor.body)
                } else {
                    Chart(weeks, id: \.label) { week in
                        BarMark(x: .value("Week", week.label), y: .value("Spent", week.total))
                            .foregroundStyle(NovaColor.action.opacity(0.75))
                            .cornerRadius(6)
                            .annotation(position: .top) {
                                Text(week.total.gbpWhole).font(.novaMicro).foregroundStyle(NovaColor.body)
                            }
                            .accessibilityLabel(week.label)
                            .accessibilityValue(week.total.gbpWhole)
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 170)
                    Text("Totals only, excluding bills and transfers.").font(.novaCaption).foregroundStyle(NovaColor.muted)
                }
            }

            NovaCard {
                SectionHeader(title: "Loans and bills", systemImage: "person.2.fill")
                if model.family.loans.isEmpty && model.family.bills.isEmpty {
                    Text("Nothing set up yet.").font(.novaCallout).foregroundStyle(NovaColor.body)
                }
                ForEach(model.family.loans.filter { $0.status != .declined }) { loan in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        HStack {
                            Text(loan.purpose).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                            Spacer()
                            Text(loan.status == .repaid ? "Repaid" : "\(loan.paidCount) of \(loan.instalments) paid")
                                .font(.novaCallout).foregroundStyle(NovaColor.body)
                        }
                        ProbabilityBar(value: loan.progress)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(loan.purpose), \(loan.paidCount) of \(loan.instalments) instalments paid")
                }
                ForEach(model.family.bills) { bill in
                    let cycles = bill.cycles().filter { $0.due <= .now }
                    let onTime = cycles.filter(\.isOnTime).count
                    HStack {
                        Text(bill.name).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                        Spacer()
                        Text("\(onTime) of \(cycles.count) on time").font(.novaCallout).foregroundStyle(NovaColor.body)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            if let piggy = model.piggy {
                NovaCard {
                    SectionHeader(title: "Piggy Bank goal", systemImage: "sterlingsign.circle.fill")
                    let progress = PiggyRules.progress(piggy, scale: model.hardshipScale)
                    HStack {
                        Text(piggy.goalName).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                        Spacer()
                        Text(UserDefaults.standard.bool(forKey: "nova.piggy.shareWithParent")
                             ? "\(piggy.saved.gbp) · \(progress.percent)" : "\(progress.percent) of goal")
                            .font(.novaCallout).foregroundStyle(NovaColor.body)
                    }
                    ProbabilityBar(value: progress, tint: NovaColor.chartWatermelon)
                    Text("Shown as a % unless \(first) chooses to share the amount.").font(.novaCaption).foregroundStyle(NovaColor.muted)
                }
                .accessibilityElement(children: .combine)
            }

            NovaCard {
                SectionHeader(title: "Safety alerts", systemImage: "bell.badge.fill")
                let alerts = viewModel.alerts(model: model)
                if alerts.isEmpty {
                    Label("No alerts. Everything looks on track.", systemImage: "checkmark.circle.fill")
                        .font(.novaCallout).foregroundStyle(NovaColor.success)
                }
                ForEach(alerts) { alert in
                    NovaNotice(kind: .warning, title: alert.title, message: alert.message)
                }
            }

            NovaCard {
                SectionHeader(title: "Never shared", systemImage: "eye.slash.fill")
                Text("Individual transactions, shop names, chat with Nova and Money Quest answers stay private.")
                    .font(.novaCallout).foregroundStyle(NovaColor.body)
            }
        }
        .navigationTitle("What your parent sees")
        .navigationBarTitleDisplayMode(.inline)
    }
}
