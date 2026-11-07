import SwiftUI

/// Money Quest game hub: the character, today's points (with the daily cap) and a chapter map.
struct MoneyQuestHubView: View {
    @Environment(AppModel.self) private var model
    private let content = MoneyQuestContent.shared

    var body: some View {
        let game = model.game
        NovaScreen {
            NovaBrandBand {
                HStack(alignment: .center, spacing: Spacing.md) {
                    ReadinessCharacter(rank: model.readiness?.score.rank ?? .bronze, size: 76)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Money Quest").font(.novaTitle)
                        Text("Short levels about real money life").font(.novaCallout).foregroundStyle(.white.opacity(0.85))
                    }
                }
                Divider().overlay(.white.opacity(0.3))
                HStack {
                    stat("\(game.pointsToday()) / \(MoneyQuestConfig.dailyPointsCap)", "points today")
                    Spacer()
                    stat("\(game.totalPoints)", "total points")
                    Spacer()
                    stat("\(game.badges.count)", game.badges.count == 1 ? "badge" : "badges")
                }
                ProbabilityBar(value: Double(game.pointsToday()) / Double(MoneyQuestConfig.dailyPointsCap), tint: .white)
                Text("Points stop at \(MoneyQuestConfig.dailyPointsCap) a day and up to \(MoneyQuestConfig.wisdomLevelsPerDay) new levels a day raise Wisdom. Play as much as you like.")
                    .font(.novaCaption).foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if content.chapters.isEmpty {
                NovaNotice(kind: .error, title: "Levels not found", message: "chapters.json is missing from the app.")
            }

            Text("Chapters").overline().padding(.top, Spacing.xs)
            VStack(spacing: 0) {
                ForEach(Array(content.chapters.enumerated()), id: \.element.id) { index, chapter in
                    NavigationLink { QuestChapterView(chapter: chapter) } label: {
                        ChapterNode(chapter: chapter, done: chapter.levels.filter { game.isComplete($0.id) }.count,
                                    hasBadge: game.badges.contains(chapter.id), isLast: index == content.chapters.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Money Quest")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.novaSection).monospacedDigit()
            Text(label).font(.novaCaption).foregroundStyle(.white.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
    }
}

/// One stop on the chapter map.
private struct ChapterNode: View {
    let chapter: QuestChapter
    let done: Int
    let hasBadge: Bool
    let isLast: Bool

    var body: some View {
        let total = chapter.levels.count
        let complete = done == total
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(spacing: 0) {
                RingView(progress: Double(done) / Double(max(1, total)), lineWidth: 4, tint: complete ? NovaColor.success : NovaColor.action) {
                    Image(systemName: complete ? "checkmark" : chapter.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(complete ? NovaColor.success : NovaColor.action)
                }
                .frame(width: 52, height: 52)
                if !isLast {
                    Rectangle().fill(NovaColor.track).frame(width: 3).frame(minHeight: 28, maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Chapter \(chapter.id)").font(.novaCaption).foregroundStyle(NovaColor.muted)
                Text(chapter.title).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    .multilineTextAlignment(.leading)
                HStack(spacing: Spacing.xs) {
                    Text("\(done) of \(total) level\(total == 1 ? "" : "s")").font(.novaCaption).foregroundStyle(NovaColor.body)
                    if hasBadge {
                        Label("Badge", systemImage: "rosette").font(.novaCaption.weight(.semibold)).foregroundStyle(NovaColor.chartYolk)
                    }
                    if chapter.needsMoreContent {
                        Text("More levels soon").font(.novaMicro).foregroundStyle(NovaColor.muted)
                    }
                }
            }
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.md)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(NovaColor.muted).padding(.top, Spacing.md).accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chapter \(chapter.id), \(chapter.title)")
        .accessibilityValue("\(done) of \(total) levels done\(hasBadge ? ", badge earned" : "")")
        .accessibilityAddTraits(.isButton)
    }
}

/// The levels in a chapter.
struct QuestChapterView: View {
    @Environment(AppModel.self) private var model
    let chapter: QuestChapter

    var body: some View {
        NovaScreen {
            NovaCard {
                Label("Chapter \(chapter.id)", systemImage: chapter.symbol).font(.novaCallout).foregroundStyle(NovaColor.action)
                Text(chapter.title).font(.novaTitle).foregroundStyle(NovaColor.brandText)
                Text(chapter.summary).font(.novaBody).foregroundStyle(NovaColor.body)
                if model.game.badges.contains(chapter.id) {
                    Label("Chapter badge earned", systemImage: "rosette").font(.novaCallout.weight(.semibold)).foregroundStyle(NovaColor.chartYolk)
                } else {
                    Text("Finish every level to earn the chapter badge.").font(.novaCaption).foregroundStyle(NovaColor.muted)
                }
            }
            ForEach(Array(chapter.levels.enumerated()), id: \.element.id) { index, level in
                NavigationLink { LevelPlayView(level: level, chapter: chapter) } label: {
                    HStack(spacing: Spacing.sm) {
                        let done = model.game.isComplete(level.id)
                        Image(systemName: done ? "checkmark.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(done ? NovaColor.success : NovaColor.action)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Level \(index + 1): \(level.title)").font(.novaHeadline).foregroundStyle(NovaColor.heading)
                            Text(level.persona).font(.novaCaption).foregroundStyle(NovaColor.body)
                                .multilineTextAlignment(.leading)
                            Text("\(level.steps.count) steps · about 2 minutes\(done ? " · best \(model.game.bestCorrect[level.id] ?? 0)/\(level.questionCount)" : "")")
                                .font(.novaMicro).foregroundStyle(NovaColor.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(NovaColor.muted).accessibilityHidden(true)
                    }
                    .padding(Spacing.md)
                    .background(NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(NovaColor.hairline))
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Chapter \(chapter.id)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
