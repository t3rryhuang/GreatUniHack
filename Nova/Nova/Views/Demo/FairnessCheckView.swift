import SwiftUI

#if DEBUG
/// DEBUG only: scores Teen A, Teen B and Teen B with poor habits side by side, using the
/// same ReadinessRules as the app. Target: Teen A and Teen B within 5% with the same rank;
/// poor habits clearly lower.
enum FairnessCheck {
    struct Result: Identifiable {
        var id: DemoProfile { profile }
        let profile: DemoProfile
        let score: ReadinessScore
        let monthlyIncome: Double
        let savings: Double
    }

    static func score(_ profile: DemoProfile, now: Date = .now) -> Result {
        let transactions = MockDataFactory.teenTransactions(profile, now: now).filter { $0.date <= now }
        let account = MockSavingsService.demoAccount(profile: profile)
        let summary = FinancialSummary.make(from: transactions, savingsBalance: account.balance)
        let family = MockDataFactory.teenFamily(profile, now: now)
        let input = ReadinessInput(
            transactions: transactions,
            summary: summary,
            savingsBalance: account.balance,
            familyPayments: family.scheduledPayments(now: now) + ReadinessRules.promisePayments(account.piggy, now: now),
            accountStart: transactions.map(\.date).min() ?? now,
            now: now,
            stage: .teen,
            savingDeposits: ReadinessRules.savingDeposits(transactions, piggy: account.piggy),
            hardshipScale: ReadinessRules.hardshipScale(transactions, now: now)
        )
        let score = ReadinessRules.score(input, progress: MockDataFactory.readinessSeed(profile, now: now)).0
        return Result(profile: profile, score: score, monthlyIncome: summary.monthlyIncome, savings: account.balance)
    }

    static func run(now: Date = .now) -> (a: Result, b: Result, poor: Result, gap: Double, fair: Bool, behaviourCounts: Bool) {
        let a = score(.teenA, now: now), b = score(.teenB, now: now), poor = score(.teenBPoorHabits, now: now)
        let gap = Double(abs(a.score.total - b.score.total)) / Double(max(1, max(a.score.total, b.score.total)))
        let fair = gap <= 0.05 && a.score.rank == b.score.rank
        let behaviourCounts = Double(poor.score.total) <= Double(min(a.score.total, b.score.total)) * 0.8
        return (a, b, poor, gap, fair, behaviourCounts)
    }
}

struct FairnessCheckView: View {
    private let result = FairnessCheck.run()

    var body: some View {
        NovaScreen {
            NovaNotice(kind: result.fair && result.behaviourCounts ? .success : .error,
                       title: result.fair && result.behaviourCounts ? "Fair: habits count, money doesn't" : "Check failed",
                       message: "Teen A and Teen B are \(result.gap.formatted(.percent.precision(.fractionLength(1)))) apart (target: 5% or less, same rank). Poor habits score \(result.poor.score.total), clearly lower.")
            NovaCard {
                SectionHeader(title: "Side by side", systemImage: "scalemass.fill")
                Grid(alignment: .trailing, horizontalSpacing: Spacing.sm, verticalSpacing: Spacing.xs) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        header(.teenA); header(.teenB); header(.teenBPoorHabits)
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    row("Income / month", result.a.monthlyIncome.gbpWhole, result.b.monthlyIncome.gbpWhole, result.poor.monthlyIncome.gbpWhole)
                    row("Savings", result.a.savings.gbpWhole, result.b.savings.gbpWhole, result.poor.savings.gbpWhole)
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(ReadinessStat.allCases) { stat in
                        row(stat.title, "\(result.a.score.points(for: stat))", "\(result.b.score.points(for: stat))", "\(result.poor.score.points(for: stat))")
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    row("Total", "\(result.a.score.total)", "\(result.b.score.total)", "\(result.poor.score.total)", bold: true)
                    row("Rank", result.a.score.rank.title, result.b.score.rank.title, result.poor.score.rank.title, bold: true)
                }
                .font(.novaCallout)
            }
            NovaCard {
                SectionHeader(title: "Checks", systemImage: "checklist")
                check("Teen A and Teen B within 5%", result.gap <= 0.05)
                check("Same rank", result.a.score.rank == result.b.score.rank)
                check("Poor habits at least 20% lower", result.behaviourCounts)
            }
            Text("Teen A and Teen B use the same habits from the same random seed; only the amounts differ. \(ReadinessScore.disclaimer)")
                .font(.novaCaption).foregroundStyle(NovaColor.muted)
        }
        .navigationTitle("Fairness check")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ profile: DemoProfile) -> some View {
        Text(profile == .teenBPoorHabits ? "B, poor" : profile.title).font(.novaCaption.weight(.semibold)).foregroundStyle(NovaColor.brandText)
    }

    private func row(_ label: String, _ a: String, _ b: String, _ c: String, bold: Bool = false) -> some View {
        GridRow {
            Text(label).foregroundStyle(NovaColor.body).gridColumnAlignment(.leading)
            Text(a); Text(b); Text(c)
        }
        .fontWeight(bold ? .semibold : .regular)
        .monospacedDigit()
        .foregroundStyle(NovaColor.heading)
        .accessibilityElement(children: .combine)
    }

    private func check(_ label: String, _ ok: Bool) -> some View {
        Label(label, systemImage: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.novaCallout).foregroundStyle(ok ? NovaColor.success : NovaColor.error)
            .accessibilityValue(ok ? "Passed" : "Failed")
    }
}
#endif
