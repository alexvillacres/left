import SwiftUI
import UIKit

// The raw ramps are ingredients, not API. Views name intent — a chip asks for
// `leftPositiveFill`, never for a specific gray — so light and dark stay in
// step from one place. Every exposed color resolves per appearance.
private enum Ramp {
    // Achromatic neutral ramp. Every RGB channel is equal by design.
    static let neutral50: UInt = 0xF5F5F5
    static let neutral100: UInt = 0xEBEBEB
    static let neutral300: UInt = 0xBDBDBD
    static let neutral500: UInt = 0x666666
    static let neutral700: UInt = 0x444444
}

extension Color {

    // MARK: - State

    // Positive stays deliberately neutral; warning and negative retain their
    // semantic color so those states remain easy to distinguish at a glance.
    static let leftPositive = Color.dynamic(light: Ramp.neutral700, dark: Ramp.neutral300)
    static let leftWarning = Color.dynamic(light: 0xA8730F, dark: 0xEDB345)
    static let leftNegative = Color.dynamic(light: 0xC63735, dark: 0xE4605E)

    // MARK: - Chip fills

    // Paired with the state foregrounds above. Neutral surfaces stay strictly
    // achromatic in both appearances.
    static let leftPositiveFill = Color.dynamic(light: Ramp.neutral100, dark: 0x2C2C2C)
    static let leftNegativeFill = Color.dynamic(light: 0xF7DEDD, dark: 0x3C1F1E)
    static let leftNeutralFill = Color.dynamic(light: Ramp.neutral100, dark: 0x2C2C2C)

    // MARK: - Meter

    // The fill colors bake in their own blending — callers must not apply
    // `.opacity()` on top, since a translucent fill over a dark track reads as
    // mud rather than as a lighter fill.
    static let meterTrack = Color.dynamic(light: Ramp.neutral50, dark: 0x1C1C1C)
    static let meterTrackBorder = Color.dynamic(light: Ramp.neutral100, dark: 0x2C2C2C)
    static let meterFill = Color.dynamic(light: 0xD1D1D1, dark: Ramp.neutral500)
    static let meterOverspentFill = Color.dynamic(light: 0xE29A99, dark: 0x8A2E2D)

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
