import SwiftUI

/// Spacing, radius and type tokens.
///
/// Spacing uses an 8pt base (Apple doc "Layout", NatWest 5.1 uses the same 4/8 rhythm).
/// Radius: pills for actions, 16pt for panels, 8pt for small controls (NatWest section 7).
/// Type: SF Pro through Dynamic Type text styles, so every label scales with the
/// user's text size. Headlines are semibold (600), per the Apple doc.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Radius {
    static let control: CGFloat = 8
    static let card: CGFloat = 16
    static let promo: CGFloat = 24
}

extension Font {
    /// Large hero numbers (balances, totals).
    static let novaHero = Font.system(.largeTitle, design: .default).weight(.semibold)
    static let novaTitle = Font.system(.title2).weight(.semibold)
    static let novaSection = Font.system(.title3).weight(.semibold)
    static let novaHeadline = Font.system(.headline)
    static let novaBody = Font.system(.body)
    static let novaCallout = Font.system(.callout)
    static let novaCaption = Font.system(.footnote)
    static let novaMicro = Font.system(.caption)
}

extension Text {
    /// Uppercase overline label used above cards (for example "THIS WEEK").
    func overline() -> some View {
        self.font(.novaMicro.weight(.semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(NovaColor.muted)
    }
}
