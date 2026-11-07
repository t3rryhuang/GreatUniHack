import Foundation

/// Demo profiles for Profile > Demo and the fairness check.
/// Teen A and Teen B have the SAME habits but very different money.
enum DemoProfile: String, CaseIterable, Identifiable, Codable, Sendable {
    case adult
    /// About £15 a week pocket money, no job, a £5 loan from a grandparent, £1 a week promise.
    case teenA
    /// About £100 a week from a part-time job plus pocket money, a £200 loan from a parent.
    case teenB
    /// Teen B's money with poor habits: late and missed payments, no saving, few quests.
    /// Used only by the fairness check.
    case teenBPoorHabits

    var id: String { rawValue }
    static let selectable: [DemoProfile] = [.adult, .teenA, .teenB]

    var stage: LifeStage { self == .adult ? .adult : .teen }

    var title: String {
        switch self {
        case .adult: "Adult"
        case .teenA: "Teen A"
        case .teenB: "Teen B"
        case .teenBPoorHabits: "Teen B, poor habits"
        }
    }

    var subtitle: String {
        switch self {
        case .adult: "Alex, 28, full-time job"
        case .teenA: "£15 a week pocket money, no job"
        case .teenB: "About £100 a week from a part-time job"
        case .teenBPoorHabits: "Teen B's money, late payments and no saving"
        }
    }

    /// The default profile for a stage.
    static func `default`(for stage: LifeStage) -> DemoProfile { stage == .teen ? .teenB : .adult }
}
