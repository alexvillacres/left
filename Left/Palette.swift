import SwiftUI
import UIKit

// Names mirror the Paper tokens (--color-plan-expenses is leftPlanExpenses),
// so design and code share one vocabulary. Two tiers:
//
//   Ramp     raw hue steps, ingredients rather than API (private).
//   Roles    public tokens that name a job (DECISIONS 008 and 027): Ink is the
//            action color, Plan hues each mean one part of the monthly plan,
//            Feedback means near-limit/behind, Surfaces and Chrome are
//            structural.
//
// Every exposed color resolves per appearance.
private enum Ramp {
    // Achromatic neutral ramp. Light mode reads from the top, dark mode from
    // the bottom; 700, 850, and 950 exist so dark surfaces can step closely.
    static let neutral0: UInt = 0xFFFFFF
    static let neutral50: UInt = 0xF3F3F3
    static let neutral100: UInt = 0xE4E4E4
    static let neutral200: UInt = 0xD4D4D4
    static let neutral400: UInt = 0xA7A7A7
    static let neutral600: UInt = 0x686868
    static let neutral700: UInt = 0x515151
    static let neutral800: UInt = 0x3A3A3A
    static let neutral850: UInt = 0x2A2A2A
    static let neutral900: UInt = 0x1C1C1C
    static let neutral950: UInt = 0x121212

    // Brand hues shared by plan marks and onboarding grounds.
    static let orange500: UInt = 0xF36334
    static let periwinkle500: UInt = 0xA5B7F1
    static let sage500: UInt = 0xA7C28A
    static let butter100: UInt = 0xF5F2AE
}

extension Color {

    // MARK: - Surfaces

    // Opaque screens and sheets paint these instead of the system backgrounds.
    static let leftBackground = Color.dynamic(light: Ramp.neutral50, dark: Ramp.neutral950)
    static let leftSheet = Color.dynamic(light: 0xFAFAFA, dark: 0x181818)
    static let leftSurface = Color.dynamic(light: Ramp.neutral0, dark: Ramp.neutral900)
    static let leftTextPrimary = Color.dynamic(light: Ramp.neutral950, dark: Ramp.neutral0)
    static let leftTextSecondary = Color.dynamic(light: 0x6E6E73, dark: 0xAAAAAF)
    // Intentionally quiet captions, help text, and utility rows.
    static let leftTextTertiary = Color.dynamic(light: 0x8E8E93, dark: 0x85858A)
    // Spending entry is always presented dark, in both appearances.
    static let leftEntryBackground = Color.dynamic(light: Ramp.neutral900, dark: Ramp.neutral900)

    // Full-screen teaching grounds from the onboarding artwork.
    static let leftOnboardingPromise = Color.dynamic(light: Ramp.periwinkle500, dark: 0x343D60)
    static let leftOnboardingProtection = Color.dynamic(light: Ramp.orange500, dark: 0x71311C)
    static let leftOnboardingRollover = Color.dynamic(light: Ramp.butter100, dark: 0x454326)

    // MARK: - Ink (actions)

    // Buttons, links, toggles, and selection. Never a brand hue. The
    // AccentColor asset must mirror leftAccent because system-rendered
    // contexts cannot read Palette.swift; change both together.
    static let leftAccent = Color.dynamic(light: Ramp.neutral950, dark: Ramp.neutral0)
    static let leftTextOnAccent = Color.dynamic(light: Ramp.neutral0, dark: Ramp.neutral950)

    // Destructive swipe actions retain white system labels in both appearances.
    // Both red fills exceed 4.5:1 contrast against white.
    static let leftDestructiveFill = Color.dynamic(light: 0xC63735, dark: 0xB83230)

    // MARK: - Plan

    // Each hue means exactly one part of the plan; income is the neutral
    // whole they divide (leftNeutralFill). Fills are for segments, dots, and
    // rings — they are not legible as text on light surfaces.
    static let leftPlanExpenses = Color.dynamic(light: Ramp.orange500, dark: Ramp.orange500)
    static let leftPlanSavings = Color.dynamic(light: Ramp.periwinkle500, dark: Ramp.periwinkle500)
    static let leftPlanSpendable = Color.dynamic(light: Ramp.sage500, dark: Ramp.sage500)

    // Text shade meets 4.5:1 on the background, surface, and spendable surface.
    static let leftPlanSpendableText = Color.dynamic(light: 0x58733C, dark: 0x8FB26A)
    static let leftPlanSpendableSurface = Color.dynamic(light: 0xEAF1E1, dark: 0x303728)

    // MARK: - Feedback

    // Only these signal a problem. Expenses orange must never stand in for them.
    // The chip behind "Needs amount"; text is darker than the warning hue so
    // it holds 4.5:1 at small sizes.
    static let leftFeedbackWarningBg = Color.dynamic(light: 0xF8EDD6, dark: 0x3A2F17)
    static let leftFeedbackWarningText = Color.dynamic(light: 0x7A5409, dark: 0xEDB345)
    static let leftFeedbackNegative = Color.dynamic(light: 0xC63735, dark: 0xE4605E)
    static let leftFeedbackNegativeBg = Color.dynamic(light: 0xF7DEDD, dark: 0x3C1F1E)

    // Replaces the allocation segments when the plan leaves nothing to spend.
    // The fills bake in their own blending — callers must not apply
    // `.opacity()` on top, since a translucent fill over a dark track reads as
    // mud rather than as a lighter fill.
    static let leftFeedbackOverspentBg = Color.dynamic(light: 0xE29A99, dark: 0x8A2E2D)

    // MARK: - Chrome (structural neutrals)

    static let leftNeutralFill = Color.dynamic(light: Ramp.neutral100, dark: Ramp.neutral850)
    // Tracks sit between the screen ground and stronger neutral fills.
    static let leftTrack = Color.dynamic(light: 0xEBEBEB, dark: 0x222222)
    static let leftDivider = Color.dynamic(light: 0xE0E0E0, dark: Ramp.neutral800)
    static let leftDividerSubtle = Color.dynamic(light: 0xEDEDED, dark: Ramp.neutral850)
    // Icon roles mirror Paper and inherit the appearance-aware neutral colors.
    static let leftBorder = leftDivider
    static let leftIconWell = leftTrack
    static let leftIconSecondary = leftTextSecondary
    // Empty fields, decorative amount prefixes, and the version label.
    static let leftPlaceholder = Color.dynamic(light: 0xA1A1A6, dark: 0x717176)
    static let leftIconMuted = Color.dynamic(light: 0xBBBBBB, dark: Ramp.neutral600)
    // Drag handle at the top of a floating sheet.
    static let leftHandle = Color.dynamic(light: Ramp.neutral200, dark: Ramp.neutral700)
    static let leftScrim = Color.black.opacity(0.2)

    // The bar shares the screen and sheet background and standard divider color.
    // Selection is carried by icon color alone.
    static let leftTabBarSurface = leftBackground
    static let leftTabBarBorder = leftDivider
    static let leftTabInactive = Color.dynamic(light: Ramp.neutral400, dark: Ramp.neutral600)

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
