import SwiftUI

#if DEBUG
/// DEBUG only: launch with `-NovaScreen <name>` to open a screen straight away
/// (for checking layouts and taking pitch screenshots), for example `-NovaScreen family`.
enum DebugScreen: String, CaseIterable, Identifiable {
    case readiness, family, parent, profile, chat, graduation, report
    case insights, history, arena, simulator

    var id: String { rawValue }

    static var requested: DebugScreen? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-NovaScreen"), index + 1 < args.count else { return nil }
        return DebugScreen(rawValue: args[index + 1].lowercased())
    }

    /// Tab index for screens that are tabs.
    var tab: Int? {
        switch self {
        case .insights: 1
        case .history: 2
        case .arena: 3
        case .simulator: 4
        default: nil
        }
    }

    @ViewBuilder var destination: some View {
        switch self {
        case .readiness: ReadinessView()
        case .family: FamilyView()
        case .parent: ParentPreviewView()
        case .profile: ProfileView()
        case .chat: ChatView()
        case .graduation: GraduationView()
        case .report: ReadinessReportView()
        case .insights, .history, .arena, .simulator: EmptyView()
        }
    }
}
#endif
