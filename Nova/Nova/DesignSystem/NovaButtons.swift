import SwiftUI

/// Pill buttons. Shape and colours follow NatWest 12.1; the press state follows the
/// Apple doc (scale to 0.95, no colour flash). Minimum height is 50pt, above the 44pt
/// touch target.
struct NovaPrimaryButtonStyle: ButtonStyle {
    var tint: Color = NovaColor.action
    var foreground: Color = NovaColor.onAction
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.novaHeadline)
            .foregroundStyle(isEnabled ? foreground : NovaColor.disabledText)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, Spacing.lg)
            .background(isEnabled ? tint : NovaColor.disabled, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

struct NovaSecondaryButtonStyle: ButtonStyle {
    var tint: Color = NovaColor.action
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.novaHeadline)
            .foregroundStyle(isEnabled ? tint : NovaColor.muted)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, Spacing.lg)
            .overlay(Capsule().strokeBorder(isEnabled ? tint : NovaColor.hairline, lineWidth: 2))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Small pill used for suggestion chips and filters.
struct NovaChipStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.novaCallout)
            .foregroundStyle(isSelected ? NovaColor.onAction : NovaColor.action)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 44)
            .background(isSelected ? NovaColor.action : NovaColor.lilac, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == NovaPrimaryButtonStyle {
    static var novaPrimary: NovaPrimaryButtonStyle { NovaPrimaryButtonStyle() }
    /// White pill on a purple band (NatWest "inverse" primary button).
    static var novaInverse: NovaPrimaryButtonStyle {
        NovaPrimaryButtonStyle(tint: .white, foreground: Color(light: 0x5E10B1, dark: 0x3C1053))
    }
    static var novaDestructive: NovaPrimaryButtonStyle {
        NovaPrimaryButtonStyle(tint: NovaColor.error, foreground: .white)
    }
}

extension ButtonStyle where Self == NovaSecondaryButtonStyle {
    static var novaSecondary: NovaSecondaryButtonStyle { NovaSecondaryButtonStyle() }
}
