import SwiftUI
import UIKit

// The raw ramps are ingredients, not API. Public tokens follow a three-layer
// contract: Accent means ours/selected/interactive, State means
// ahead/near-limit/behind, and Chrome is structural furniture. At rebrand time,
// only Accent (plus the AccentColor asset) should need editing. Every exposed
// color resolves per appearance.
private enum Ramp {
    // Achromatic neutral ramp. Every RGB channel is equal by design.
    static let neutral50: UInt = 0xF5F5F5
    static let neutral100: UInt = 0xEBEBEB
    static let neutral300: UInt = 0xBDBDBD
    static let neutral500: UInt = 0x666666
    static let neutral700: UInt = 0x444444
    static let neutralDark700: UInt = 0x2C2C2C
    static let neutralDark800: UInt = 0x1C1C1C
}

extension Color {

    // MARK: - Accent (brand identity)

    // Temporarily neutral to preserve today's global tint; this goes to the
    // brand color at rebrand. The other accent tokens intentionally retain the
    // current fern palette until then. The AccentColor asset must mirror
    // leftAccent because system-rendered contexts cannot read Palette.swift;
    // change both together at rebrand.
    static let leftAccent = Color.dynamic(light: Ramp.neutral700, dark: Ramp.neutral300)
    static let leftAccentStrong = Color.dynamic(light: 0x336D29, dark: 0x509341)
    static let leftAccentFill = Color.dynamic(light: 0xD6F1CE, dark: 0x1C4F14)
    static let leftOnAccentFill = Color.dynamic(light: 0x003100, dark: 0xD6F1CE)
    static let leftAccentMuted = Color.dynamic(light: 0x336D29, dark: 0x8DDC70)
    static let leftOnAccent = Color.dynamic(light: 0xC6E6BC, dark: 0xD6F1CE)

    // MARK: - State

    // Positive stays deliberately neutral; warning and negative retain their
    // semantic color so those states remain easy to distinguish at a glance.
    static let leftPositive = Color.dynamic(light: Ramp.neutral700, dark: Ramp.neutral300)
    static let leftWarning = Color.dynamic(light: 0xA8730F, dark: 0xEDB345)
    static let leftNegative = Color.dynamic(light: 0xC63735, dark: 0xE4605E)

    // Paired with the state foregrounds above. Neutral surfaces stay strictly
    // achromatic in both appearances.
    static let leftPositiveFill = Color.dynamic(light: Ramp.neutral100, dark: Ramp.neutralDark700)
    static let leftNegativeFill = Color.dynamic(light: 0xF7DEDD, dark: 0x3C1F1E)

    // MARK: - Chrome (structural neutrals)

    // The fill colors bake in their own blending — callers must not apply
    // `.opacity()` on top, since a translucent fill over a dark track reads as
    // mud rather than as a lighter fill.
    static let meterTrack = Color.dynamic(light: Ramp.neutral50, dark: Ramp.neutralDark800)
    static let meterTrackBorder = Color.dynamic(light: Ramp.neutral100, dark: Ramp.neutralDark700)
    static let meterFill = Color.dynamic(light: 0xD1D1D1, dark: Ramp.neutral500)
    static let meterWarningFill = Color.dynamic(light: 0xE8C27A, dark: 0x8A6A1F)
    static let meterOverspentFill = Color.dynamic(light: 0xE29A99, dark: 0x8A2E2D)

    static let leftNeutralFill = Color.dynamic(light: Ramp.neutral100, dark: Ramp.neutralDark700)

    // The capsule reads as elevated, not translucent. In light mode it matches
    // the page and separates on shadow alone; shadows vanish against black, so
    // dark mode lifts the surface instead.
    static let leftTabBarSurface = Color.dynamic(light: 0xFFFFFF, dark: Ramp.neutralDark800)
    static let leftTabBarBorder = Color.dynamic(light: Ramp.neutral100, dark: Ramp.neutralDark700)
    static let leftTabActiveFill = Color.dynamic(light: Ramp.neutral100, dark: Ramp.neutralDark700)
    static let leftMonthYear = Color.dynamic(light: 0x727671, dark: 0xBBBFBA)
    static let leftMonthBorder = Color.dynamic(light: 0xE8ECE7, dark: 0x3E413D)
    static let leftDurationDivider = Color.dynamic(light: 0xEDEFEC, dark: 0x3E413D)

    // MARK: - Resolution

    private static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
