import SwiftUI

/// Today's quest with live progress, and the shield message when it saved the streak.
struct DailyQuestCard: View {
    @Environment(AppModel.self) private var model
    let quest: DailyQuest
    let streak: Int
    let recentShield: ShieldEvent?

    var body: some View {
        let spent = ReadinessRules.spend(for: quest, in: model.transactions)
        let over = spent > quest.limit
        NovaCard {
            SectionHeader(title: "Daily quest", systemImage: "target") {
                Label("\(streak)", systemImage: "flame.fill")
                    .font(.novaCallout.weight(.semibold))
                    .foregroundStyle(NovaColor.chartTangerine)
                    .accessibilityLabel("\(streak)-day streak")
            }
            HStack(spacing: Spacing.sm) {
                CategoryIcon(category: quest.category)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(quest.title).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                        .fixedSize(horizontal: false, vertical: true)
                    ProbabilityBar(value: quest.limit > 0 ? spent / quest.limit : 0, tint: over ? NovaColor.error : quest.category.color)
                    Text(statusText(spent: spent, over: over))
                        .font(.novaCaption)
                        .foregroundStyle(quest.status == .completed ? NovaColor.success : over ? NovaColor.error : NovaColor.body)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(quest.title)
            .accessibilityValue(statusText(spent: spent, over: over))
            if let recentShield {
                Label(recentShield.message, systemImage: "shield.lefthalf.filled")
                    .font(.novaCallout.weight(.semibold))
                    .foregroundStyle(NovaColor.info)
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NovaColor.tonal, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }
        }
    }

    private func statusText(spent: Double, over: Bool) -> String {
        switch quest.status {
        case .completed: "Quest complete. Your streak grows."
        case .missed: "Missed. Tomorrow is a new quest."
        case .shielded: "Your shield covered this one."
        case .pending:
            over ? "\(spent.gbp) spent, over the limit. Your shield can cover one miss a month."
                 : "\(spent.gbp) of \(quest.limit.gbpWhole) so far. Checked at the end of the day."
        }
    }
}

/// The weekly boss: the next bill due this week.
struct WeeklyBossCard: View {
    let boss: WeeklyBoss

    var body: some View {
        NovaCard {
            SectionHeader(title: "Weekly boss", systemImage: "bolt.shield.fill") {
                Text(statusTitle)
                    .font(.novaCaption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, Spacing.xs).padding(.vertical, 2)
                    .background(statusColor.opacity(0.14), in: Capsule())
            }
            HStack(alignment: .firstTextBaseline) {
                Text(boss.name).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                Spacer()
                Text(boss.amount.gbp).font(.novaHeadline).foregroundStyle(NovaColor.heading).monospacedDigit()
            }
            Text(detail).font(.novaCallout).foregroundStyle(NovaColor.body)
        }
        .accessibilityElement(children: .combine)
    }

    private var dueText: String {
        Calendar.current.isDateInToday(boss.due) ? "today" : boss.due.formatted(.dateTime.weekday(.wide))
    }

    private var detail: String {
        switch boss.status {
        case .upcoming: "Due \(dueText). Pay it on time to defeat this week's boss and raise Reliability."
        case .defeated: "Paid on time. Boss defeated."
        case .missed: "This one is overdue. Pay it as soon as you can."
        }
    }

    private var statusTitle: String {
        switch boss.status {
        case .upcoming: "Due \(dueText)"
        case .defeated: "Defeated"
        case .missed: "Overdue"
        }
    }

    private var statusColor: Color {
        switch boss.status {
        case .upcoming: NovaColor.action
        case .defeated: NovaColor.success
        case .missed: NovaColor.error
        }
    }
}
