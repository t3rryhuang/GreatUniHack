import SwiftUI

/// Friend and school leagues: points and improvement only, never money.
struct LeagueView: View {
    @Environment(AppModel.self) private var model
    @State private var kind: League.Kind = .friends
    @State private var leagues: [League] = []

    var body: some View {
        NovaScreen {
            Picker("League", selection: $kind) {
                ForEach(League.Kind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            NovaNotice(kind: .info, title: "Points and improvement only",
                       message: "Leagues rank this week's Money Quest points, then how much your score improved. Nobody sees anyone's money.")
            if let league = leagues.first(where: { $0.kind == kind }) {
                NovaCard {
                    SectionHeader(title: league.name, systemImage: "person.3.fill")
                    ForEach(Array(league.entries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: Spacing.sm) {
                            Text("\(index + 1)").font(.novaHeadline).foregroundStyle(index < 3 ? NovaColor.action : NovaColor.muted).frame(width: 26)
                            ReadinessCharacter(rank: entry.rank, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.isCurrentUser ? "\(entry.name) (you)" : entry.name)
                                    .font(.novaBody.weight(entry.isCurrentUser ? .semibold : .regular)).foregroundStyle(NovaColor.heading)
                                HStack(spacing: Spacing.xs) {
                                    Text(entry.rank.title).foregroundStyle(entry.rank.color)
                                    Label("\(entry.badges)", systemImage: "rosette").foregroundStyle(NovaColor.body)
                                    Text("\(entry.improvement >= 0 ? "+" : "")\(entry.improvement) this month").foregroundStyle(NovaColor.body)
                                }
                                .font(.novaCaption)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("\(entry.weeklyPoints)").font(.novaHeadline).foregroundStyle(NovaColor.heading).monospacedDigit()
                                Text("points").font(.novaMicro).foregroundStyle(NovaColor.muted)
                            }
                        }
                        .padding(.vertical, Spacing.xxs)
                        .background(entry.isCurrentUser ? NovaColor.lilac.opacity(0.6) : .clear, in: RoundedRectangle(cornerRadius: Radius.control))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(index + 1). \(entry.isCurrentUser ? "You" : entry.name), \(entry.rank.title) rank, \(entry.badges) badges, \(entry.weeklyPoints) points this week, \(entry.improvement >= 0 ? "up" : "down") \(abs(entry.improvement)) this month")
                    }
                }
            } else {
                LoadingCard(label: "Loading leagues…")
            }
        }
        .navigationTitle("Leagues")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let me = LeagueEntry(name: model.user?.name ?? "You", rank: model.readiness?.score.rank ?? .bronze,
                                 badges: model.game.badges.count + (model.piggy?.goalReachedAt == nil ? 0 : 1),
                                 weeklyPoints: LeagueRules.weeklyPoints(model.game), improvement: model.readiness?.monthChange ?? 0,
                                 isCurrentUser: true)
            leagues = await model.services.leagues.leagues(me: me)
        }
    }
}
