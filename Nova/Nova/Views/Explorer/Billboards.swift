import SwiftUI

/// What a billboard says. Built from live data: the next quest, the park total,
/// the player's savings streak (as % and months, never £) and in-game events.
struct BillboardContent: Hashable {
    let kicker: String
    let title: String
    let detail: String
    let symbol: String
    let progress: Double?

    @MainActor
    init(kind: BillboardKind, model: AppModel, nextQuest: ExplorerNPC?) {
        switch kind {
        case .welcome:
            kicker = "NatWest Nova Hackathon"
            title = "Welcome to the Nancy Rothwell Building"
            detail = "Meet Remi for a new look, then head out into Manchester."
            symbol = "building.2.fill"
            progress = nil
        case .nextQuest:
            kicker = "Upcoming quest"
            title = nextQuest.map { "\($0.name): \($0.line)" } ?? "All quests done. Legend!"
            detail = nextQuest.map { "Find \($0.name) the \($0.role.lowercased()) near \(ExplorerZone.at($0.position).title)." } ?? "Replay any quest for fun."
            symbol = "map.fill"
            progress = nil
        case .park:
            let status = model.park ?? ParkStatus(total: 0, contributors: 0)
            let stage = status.stage
            kicker = "Community Park"
            if let next = stage.next {
                title = "\(status.total.formatted()) / \(next.threshold.formatted()) points to the \(next.title.lowercased())"
                progress = Double(status.total - stage.threshold) / Double(next.threshold - stage.threshold)
            } else {
                title = "The skatepark is open! \(status.total.formatted()) points"
                progress = 1
            }
            detail = "\(status.contributors.formatted()) players have helped. Finish quests to earn park points."
            symbol = "tree.fill"
        case .savings:
            let piggy = model.piggy
            let pct = piggy.map { PiggyRules.progress($0, scale: model.hardshipScale) } ?? 0
            kicker = "Your Piggy Bank"
            title = piggy.map { "\(pct.percent) of your \($0.goalName.lowercased()) goal" } ?? "Start a Piggy Bank goal"
            detail = "Every 25% of YOUR goal earns XP here. Same XP for every goal size."
            symbol = "sterlingsign.circle.fill"
            progress = piggy == nil ? nil : pct
        case .event:
            kicker = "This week in the city"
            title = "Scam Awareness Week"
            detail = "Talk to Vic in the Northern Quarter and Sam at the venue to spot the traps."
            symbol = "exclamationmark.shield.fill"
            progress = nil
        }
    }
}

struct BillboardView: View {
    let content: BillboardContent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(content.kicker.uppercased(), systemImage: content.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.75, green: 0.6, blue: 0.9))
                Spacer()
                Text("Nova").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white.opacity(0.8))
            }
            Text(content.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(content.detail)
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if let progress = content.progress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(Color(red: 0.95, green: 0.76, blue: 0.19)).frame(width: proxy.size.width * min(1, max(0.02, progress)))
                    }
                }
                .frame(height: 14)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .background(
            LinearGradient(colors: [Color(red: 0.24, green: 0.06, blue: 0.33), Color(red: 0.37, green: 0.06, blue: 0.69)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.4), lineWidth: 6))
    }
}
