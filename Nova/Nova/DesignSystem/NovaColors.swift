import SwiftUI
import UIKit

/// Colour tokens for Nova.
///
/// Values come from `docs/natwest-brand-guide.md` (sections 2 and 3).
/// Following `docs/DESIGN-apple.md`, there is a single interactive accent
/// (NatWest bright purple), and depth comes from surface colour rather than shadows.
/// Every token has a light and a dark value so the app follows the system appearance.
enum NovaColor {
    // MARK: Brand

    /// The one "tap me" colour: buttons, links, selected controls.
    static let action = Color(light: 0x5E10B1, dark: 0xBE99E6)
    /// Text and icons placed on top of `action`.
    static let onAction = Color(light: 0xFFFFFF, dark: 0x3C1053)
    /// Headline and brand text.
    static let brandText = Color(light: 0x5A287D, dark: 0xFFFFFF)
    /// Dark brand band (Apple's "dark tile"), used for hero sections.
    static let brandBand = Color(light: 0x5A287D, dark: 0x3C1053)
    /// Darkest brand surface.
    static let regal = Color(light: 0x3C1053, dark: 0x2A0B3B)
    /// Light brand tint used for chips and selected rows.
    static let lilac = Color(light: 0xF2EAF9, dark: 0x2C2C2C)
    /// Progress tracks and slider tracks.
    static let track = Color(light: 0xE6DEEB, dark: 0x414141)

    // MARK: Surfaces

    static let page = Color(light: 0xF2F2F8, dark: 0x121212)
    static let card = Color(light: 0xFFFFFF, dark: 0x1E1E1E)
    static let tonal = Color(light: 0xF2F2F8, dark: 0x2A2A2C)
    static let hairline = Color(light: 0xE0E0E6, dark: 0x333333)

    // MARK: Text

    static let heading = Color(light: 0x2C2C2C, dark: 0xFFFFFF)
    static let body = Color(light: 0x616161, dark: 0xCCCCCC)
    static let muted = Color(light: 0x7A7A7A, dark: 0x9A9A9A)

    // MARK: Disabled (NatWest 12.1: #B3B3B3 fill, #5C5C5C text)

    static let disabled = Color(light: 0xB3B3B3, dark: 0x333333)
    static let disabledText = Color(light: 0x5C5C5C, dark: 0x8A8A8A)

    // MARK: Feedback

    static let success = Color(light: 0x008E4E, dark: 0x3AD356)
    static let error = Color(light: 0xDF2B40, dark: 0xEF5A6B)
    static let warning = Color(light: 0xB37F00, dark: 0xFBB200)
    static let info = Color(light: 0x0B72D0, dark: 0x2D90FD)

    static let successTint = Color(light: 0xECF4ED, dark: 0x1A3920)
    static let errorTint = Color(light: 0xFAE9EC, dark: 0x3C1323)
    static let warningTint = Color(light: 0xFFF8E5, dark: 0x41320E)

    // MARK: Data visualisation (brand guide 2.6)

    static let chartAubergine = Color(light: 0x8138E0, dark: 0xB388EC)
    static let chartBlueberry = Color(light: 0x006FE6, dark: 0x66A9F0)
    static let chartBroccoli = Color(light: 0x2A863B, dark: 0x89E59A)
    static let chartWatermelon = Color(light: 0xE51565, dark: 0xEF73A3)
    static let chartTangerine = Color(light: 0xDB3700, dark: 0xE98766)
    static let chartYolk = Color(light: 0x9E7207, dark: 0xFDD166)
    static let chartChampion = Color(light: 0x5A287D, dark: 0xCDAFF3)
    static let chartGrey = Color(light: 0x9A9A9A, dark: 0x6C6C6C)

    // MARK: Pastels (soft chart fills; text on them uses the matching `chart…` colour)

    static let pastelBlue = Color(light: 0xD3E4F9, dark: 0x27384D)
    static let pastelGreen = Color(light: 0xD3EDDA, dark: 0x233D2B)
    static let pastelYellow = Color(light: 0xFBEDC4, dark: 0x45391A)
    static let pastelPeach = Color(light: 0xFADBCB, dark: 0x4A2B1F)
    static let pastelLilac = Color(light: 0xE6DAF6, dark: 0x352847)
    static let pastelPink = Color(light: 0xF8D7E4, dark: 0x472433)
}

extension Color {
    /// A colour that switches between two hex values with the system appearance.
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
