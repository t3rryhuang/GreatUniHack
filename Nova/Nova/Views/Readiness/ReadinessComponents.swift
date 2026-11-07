import SwiftUI

extension ReadinessRank {
    var color: Color {
        switch self {
        case .bronze: NovaColor.chartTangerine
        case .silver: NovaColor.chartGrey
        case .gold: NovaColor.chartYolk
        case .platinum: NovaColor.chartBlueberry
        case .diamond: NovaColor.chartAubergine
        }
    }

    /// The character's look at this rank: it starts walking and ends at the summit.
    var figure: String {
        switch self {
        case .bronze: "figure.walk"
        case .silver: "figure.run"
        case .gold: "figure.hiking"
        case .platinum: "figure.climbing"
        case .diamond: "figure.mind.and.body"
        }
    }

    var badge: String {
        switch self {
        case .bronze: "shield.fill"
        case .silver: "star.fill"
        case .gold: "medal.fill"
        case .platinum: "crown.fill"
        case .diamond: "diamond.fill"
        }
    }

    var characterTitle: String {
        switch self {
        case .bronze: "Starter"
        case .silver: "Runner"
        case .gold: "Hiker"
        case .platinum: "Climber"
        case .diamond: "Summiteer"
        }
    }
}

/// The Readiness character, drawn with SF Symbols. Its pose and badge change with the rank.
struct ReadinessCharacter: View {
    let rank: ReadinessRank
    var size: CGFloat = 120

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(rank.color.opacity(0.16))
                .overlay(Circle().strokeBorder(rank.color, lineWidth: max(2, size * 0.03)))
                .overlay(
                    Image(systemName: rank.figure)
                        .font(.system(size: size * 0.48, weight: .semibold))
                        .foregroundStyle(rank.color)
                )
                .frame(width: size, height: size)
            Image(systemName: rank.badge)
                .font(.system(size: size * 0.16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size * 0.32, height: size * 0.32)
                .background(rank.color, in: Circle())
                .overlay(Circle().strokeBorder(NovaColor.card, lineWidth: max(2, size * 0.025)))
        }
        .accessibilityElement()
        .accessibilityLabel("\(rank.title) \(rank.characterTitle) character")
    }
}

/// "This is a readiness score, not a credit score." Shown wherever the score appears.
struct ReadinessDisclaimer: View {
    var body: some View {
        Label(ReadinessScore.disclaimer, systemImage: "info.circle")
            .font(.novaCaption)
            .foregroundStyle(NovaColor.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One stat: icon, name, real-world equivalent and a 0-200 bar.
struct StatBarRow: View {
    let score: StatScore

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: score.stat.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(NovaColor.action)
                .frame(width: 40, height: 40)
                .background(NovaColor.lilac, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(score.stat.title).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    Spacer()
                    Text("\(score.points)").font(.novaHeadline).foregroundStyle(NovaColor.heading).monospacedDigit()
                    Text("/ \(ReadinessStat.maxPoints)").font(.novaCaption).foregroundStyle(NovaColor.muted)
                }
                ProbabilityBar(value: Double(score.points) / Double(ReadinessStat.maxPoints))
                Text("Like \(score.stat.creditFactor.lowercased()) · \(score.detail)")
                    .font(.novaCaption)
                    .foregroundStyle(NovaColor.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(NovaColor.muted).accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score.stat.title), \(score.points) of \(ReadinessStat.maxPoints)")
        .accessibilityValue("Real-world equivalent: \(score.stat.creditFactor). \(score.detail)")
        .accessibilityHint("Shows what it measures and how to raise it")
        .accessibilityAddTraits(.isButton)
    }
}

/// Compact Readiness card for Home and Profile.
struct ReadinessSummaryCard: View {
    let snapshot: ReadinessSnapshot

    var body: some View {
        let score = snapshot.score
        HStack(spacing: Spacing.md) {
            ReadinessCharacter(rank: score.rank, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text("Readiness Score").overline()
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text("\(score.total)").font(.novaTitle).foregroundStyle(NovaColor.heading).monospacedDigit()
                    Text("\(score.rank.title)").font(.novaCallout.weight(.semibold)).foregroundStyle(NovaColor.action)
                }
                HStack(spacing: Spacing.sm) {
                    if snapshot.monthChange != 0 {
                        Label("\(snapshot.monthChange > 0 ? "+" : "")\(snapshot.monthChange) this month",
                              systemImage: snapshot.monthChange > 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundStyle(snapshot.monthChange > 0 ? NovaColor.success : NovaColor.error)
                    }
                    Label("\(snapshot.streak) days", systemImage: "flame.fill").foregroundStyle(NovaColor.body)
                }
                .font(.novaCaption)
                Text("Not a credit score").font(.novaMicro).foregroundStyle(NovaColor.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(NovaColor.muted).accessibilityHidden(true)
        }
        .padding(Spacing.md)
        .background(NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(NovaColor.hairline))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Readiness Score \(score.total) of 1000, \(score.rank.title) rank. \(snapshot.monthChange >= 0 ? "Up" : "Down") \(abs(snapshot.monthChange)) this month. \(snapshot.streak)-day streak. \(ReadinessScore.disclaimer)")
        .accessibilityAddTraits(.isButton)
    }
}
