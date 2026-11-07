import Foundation

/// Who Nova is talking to. Teens (16-17) get Teen mode: no stakes, no credit
/// talk, family loans and the graduation path. Under-16s are out of scope.
enum LifeStage: String, Codable, CaseIterable, Identifiable, Sendable {
    case teen, adult

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teen: "Teen"
        case .adult: "Adult"
        }
    }

    /// Teen if under 18; adult if 18 or over, or if we don't know the date of birth.
    static func from(dateOfBirth: Date?, now: Date = .now, calendar: Calendar = .current) -> LifeStage {
        guard let dateOfBirth, let age = calendar.dateComponents([.year], from: dateOfBirth, to: now).year else { return .adult }
        return age < 18 ? .teen : .adult
    }
}

extension UserProfile {
    var stage: LifeStage { LifeStage.from(dateOfBirth: dateOfBirth) }

    var age: Int? {
        guard let dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now).year
    }
}
