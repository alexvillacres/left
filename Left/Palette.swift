import SwiftUI
import UIKit

// Names mirror the Paper tokens (--color-plan-expenses is leftPlanExpenses),
// so design and code share one vocabulary. Three tiers:
//
//   Ramp     raw hue steps, ingredients rather than API (private).
//   Roles    public tokens that name a job (DECISIONS 008 and 027): Ink is the
//            action color, Plan hues each mean one part of the monthly plan,
//            Feedback means near-limit/behind, Surfaces and Chrome are
//            structural.
//   Grounds  per-screen and per-ticket colors built from the ramp (029, 030).
//
// Every exposed color resolves per appearance.
private enum Ramp {
    // Green-gray neutral ramp. Light mode reads from the top, dark mode from
    // the bottom; 700, 850, and 950 exist so dark surfaces can step closely.
    static let neutral0: UInt = 0xFBFDF7
    static let neutral50: UInt = 0xF5F7F1
    static let neutral100: UInt = 0xE8EAE4
    static let neutral200: UInt = 0xD4D6D0
    static let neutral300: UInt = 0xC5C7C1
    static let neutral400: UInt = 0xA7A9A3
    static let neutral500: UInt = 0x858782
    static let neutral600: UInt = 0x686A65
    static let neutral700: UInt = 0x515350
    static let neutral800: UInt = 0x3A3C37
    static let neutral850: UInt = 0x2A2C27
    static let neutral900: UInt = 0x1C1E19
    static let neutral950: UInt = 0x121410

    // Hue steps share one scale: 100 is a pale tint for a ground, 200 is the
    // solid control fill on that tint, 500 is the brand mark, 600 is a darker
    // rule, and 700 is secondary ink that meets 4.5:1 on a 100 and its 200.
    static let orange100: UInt = 0xFBD9CA
    static let orange200: UInt = 0xE7C8BA
    static let orange500: UInt = 0xF36334
    static let orange700: UInt = 0x5B3A2E

    static let periwinkle100: UInt = 0xDDE4F8
    static let periwinkle200: UInt = 0xCBD2E4
    static let periwinkle500: UInt = 0xA5B7F1
    static let periwinkle600: UInt = 0x99AADF
    static let periwinkle700: UInt = 0x414858

    static let sage100: UInt = 0xD9E6C9
    static let sage200: UInt = 0xC8D8B5
    static let sage500: UInt = 0xA7C28A
    static let sage700: UInt = 0x4A5640

    static let butter100: UInt = 0xF5F2AE
    static let butter200: UInt = 0xE3E0A1
    static let butter700: UInt = 0x5C5C40

    static let tan100: UInt = 0xE7E2D0
    static let tan200: UInt = 0xD6D2C1
    static let tan700: UInt = 0x59584F
}

extension Color {

    // MARK: - Surfaces

    // Opaque screens and sheets paint these instead of the system backgrounds.
    static let leftBackground = Color.dynamic(light: Ramp.neutral0, dark: Ramp.neutral950)
    static let leftSurface = Color.dynamic(light: Ramp.neutral50, dark: Ramp.neutral900)
    // Spending entry is always presented dark, in both appearances.
    static let leftEntryBackground = Color.dynamic(light: Ramp.neutral900, dark: Ramp.neutral900)

    // Full-screen teaching grounds from the onboarding artwork.
    static let leftOnboardingPromise = Color.dynamic(light: Ramp.periwinkle500, dark: 0x343D60)
    static let leftOnboardingProtection = Color.dynamic(light: Ramp.orange500, dark: 0x71311C)
    static let leftOnboardingRollover = Color.dynamic(light: Ramp.butter100, dark: 0x454326)
    static let leftOnboardingCircle = Color.dynamic(light: 0xFFFFFF, dark: 0xFFFFFF)

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
    static let leftFeedbackWarning = Color.dynamic(light: 0xA8730F, dark: 0xEDB345)
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

    // MARK: - Weekly report (DECISIONS 029)

    // Celebration grounds, not plan meaning. The ticket keeps its light ground
    // in both appearances because the artwork is drawn on light paper, so each
    // role resolves to the same value in dark mode. Every tint is solid: labels
    // meet 4.5:1 on their ground, and nothing layers opacity over the artwork.
    static let leftReportTan = Color.dynamic(light: Ramp.tan100, dark: Ramp.tan100)
    static let leftReportTanLabel = Color.dynamic(light: 0x636259, dark: 0x636259)
    static let leftReportTanRule = Color.dynamic(light: Ramp.tan200, dark: Ramp.tan200)
    static let leftReportTanPerforation = Color.dynamic(light: 0xBCB9AA, dark: 0xBCB9AA)
    static let leftReportTanStub = Color.dynamic(light: 0xF2EFE5, dark: 0xF2EFE5)

    static let leftReportPeriwinkle = Color.dynamic(light: Ramp.periwinkle500, dark: Ramp.periwinkle500)
    static let leftReportPeriwinkleLabel = Color.dynamic(light: 0x414858, dark: 0x414858)
    static let leftReportPeriwinkleRule = Color.dynamic(light: Ramp.periwinkle600, dark: Ramp.periwinkle600)
    static let leftReportPeriwinklePerforation = Color.dynamic(light: 0x8896C4, dark: 0x8896C4)
    static let leftReportPeriwinkleStub = Color.dynamic(light: 0xCED7F7, dark: 0xCED7F7)

    static let leftReportButter = Color.dynamic(light: Ramp.butter100, dark: Ramp.butter100)
    static let leftReportButterLabel = Color.dynamic(light: 0x68684C, dark: 0x68684C)
    static let leftReportButterRule = Color.dynamic(light: Ramp.butter200, dark: Ramp.butter200)
    static let leftReportButterPerforation = Color.dynamic(light: 0xC8C68E, dark: 0xC8C68E)
    static let leftReportButterStub = Color.dynamic(light: 0xFAF8D2, dark: 0xFAF8D2)

    // Ink on every report ground, regardless of appearance.
    static let leftReportInk = Color.dynamic(light: Ramp.neutral950, dark: Ramp.neutral950)

    // The one intentionally translucent color: its job is to let Today show
    // through behind the ticket.
    static let leftReportScrim = Color.black.opacity(0.4)

    // MARK: - Screen grounds (DECISIONS 030)

    // Each main tab opens on one light ground that stays light in dark mode,
    // so the tab reads the same at night. Like the report tickets, every role
    // resolves to the same value in both appearances. Secondary ink meets
    // 4.5:1 on both the ground and its control fill. A ground is the 100 step
    // of its hue, its fill is the 200, and secondary ink is the 700.
    static let leftGroundTextPrimary = Color.dynamic(light: Ramp.neutral950, dark: Ramp.neutral950)

    static let leftGroundToday = Color.dynamic(light: Ramp.butter100, dark: Ramp.butter100)
    static let leftGroundTodayFill = Color.dynamic(light: Ramp.butter200, dark: Ramp.butter200)
    static let leftGroundTodayTextSecondary = Color.dynamic(light: Ramp.butter700, dark: Ramp.butter700)

    static let leftGroundActivity = Color.dynamic(light: Ramp.tan100, dark: Ramp.tan100)
    static let leftGroundActivityFill = Color.dynamic(light: Ramp.tan200, dark: Ramp.tan200)
    static let leftGroundActivityTextSecondary = Color.dynamic(light: Ramp.tan700, dark: Ramp.tan700)

    // Plan's ground is a pale spendable, since its headline is the spendable
    // amount (027).
    static let leftGroundPlan = Color.dynamic(light: Ramp.sage100, dark: Ramp.sage100)
    static let leftGroundPlanFill = Color.dynamic(light: Ramp.sage200, dark: Ramp.sage200)
    static let leftGroundPlanTextSecondary = Color.dynamic(light: Ramp.sage700, dark: Ramp.sage700)

    // Plan detail screens (Income, Expenses, Savings) open on the tint of the
    // plan part they edit. Income is the neutral whole, so it takes the neutral
    // ramp rather than a hue.
    static let leftGroundIncome = Color.dynamic(light: Ramp.neutral100, dark: Ramp.neutral100)
    static let leftGroundIncomeFill = Color.dynamic(light: Ramp.neutral200, dark: Ramp.neutral200)
    static let leftGroundIncomeTextSecondary = Color.dynamic(light: Ramp.neutral700, dark: Ramp.neutral700)

    static let leftGroundExpenses = Color.dynamic(light: Ramp.orange100, dark: Ramp.orange100)
    static let leftGroundExpensesFill = Color.dynamic(light: Ramp.orange200, dark: Ramp.orange200)
    static let leftGroundExpensesTextSecondary = Color.dynamic(light: Ramp.orange700, dark: Ramp.orange700)

    static let leftGroundSavings = Color.dynamic(light: Ramp.periwinkle100, dark: Ramp.periwinkle100)
    static let leftGroundSavingsFill = Color.dynamic(light: Ramp.periwinkle200, dark: Ramp.periwinkle200)
    static let leftGroundSavingsTextSecondary = Color.dynamic(light: Ramp.periwinkle700, dark: Ramp.periwinkle700)

    // MARK: - Chrome (structural neutrals)

    static let leftNeutralFill = Color.dynamic(light: Ramp.neutral100, dark: Ramp.neutral850)
    static let leftDivider = Color.dynamic(light: Ramp.neutral200, dark: Ramp.neutral800)
    // Decorative prefixes such as a currency symbol beside an entered amount.
    static let leftPlaceholder = Color.dynamic(light: Ramp.neutral300, dark: Ramp.neutral700)
    // Drag handle at the top of a floating sheet.
    static let leftHandle = Color.dynamic(light: Ramp.neutral400, dark: Ramp.neutral600)

    // The bar is opaque, not a material, and separates from content on a
    // hairline. Selection is carried by icon color alone.
    static let leftTabBarSurface = Color.dynamic(light: Ramp.neutral0, dark: Ramp.neutral900)
    static let leftTabBarBorder = Color.dynamic(light: Ramp.neutral100, dark: Ramp.neutral850)
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
