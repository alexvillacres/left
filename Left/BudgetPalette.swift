import SwiftUI
import UIKit

extension Color {
    // MARK: - Primary ramp: Fern

    static let fern50 = Color(hex: 0xEDF9E9)
    static let fern100 = Color(hex: 0xD6F1CE)
    static let fern200 = Color(hex: 0xB6E8A5)
    static let fern300 = Color(hex: 0x8DDC70)
    static let fern400 = Color(hex: 0x6EBB58)
    static let fern500 = Color(hex: 0x509341)
    static let fern600 = Color(hex: 0x336D29)
    static let fern700 = Color(hex: 0x1C4F14)
    static let fern800 = Color(hex: 0x003100)
    static let fern900 = Color(hex: 0x031C03)
    static let fern950 = Color(hex: 0x020F02)

    // MARK: - Semantic accents

    static let budgetWarm = Color(hex: 0xEDB345)
    static let budgetOverBudget = Color(hex: 0xDB4241)
    static let budgetInfo = Color(hex: 0x2B88C0)
    static let budgetCanvas = Color(hex: 0xF4F6EF)

    // MARK: - Neutrals

    static let budgetNeutral0 = Color(hex: 0xF9FDF8)
    static let budgetNeutral50 = Color(hex: 0xF2F6F1)
    static let budgetNeutral100 = Color(hex: 0xE8ECE7)
    static let budgetNeutral200 = Color(hex: 0xD5D9D4)
    static let budgetNeutral300 = Color(hex: 0xBBBFBA)
    static let budgetNeutral400 = Color(hex: 0x969995)
    static let budgetNeutral500 = Color(hex: 0x727671)
    static let budgetNeutral600 = Color(hex: 0x565955)
    static let budgetNeutral700 = Color(hex: 0x3E413D)
    static let budgetNeutral800 = Color(hex: 0x242724)
    static let budgetNeutral900 = Color(hex: 0x10120F)
    static let budgetNeutral950 = Color(hex: 0x050604)

    // MARK: - Product semantics

    static let budgetBackground = Color.budgetDynamic(light: 0xF4F6EF, dark: 0x050604)
    static let budgetSurface = Color.budgetDynamic(light: 0xF9FDF8, dark: 0x10120F)
    static let budgetSubtleSurface = Color.budgetDynamic(light: 0xF2F6F1, dark: 0x242724)
    static let budgetDivider = Color.budgetDynamic(light: 0xD5D9D4, dark: 0x3E413D)

    static let budgetPrimaryAction = Color.budgetDynamic(light: 0x10120F, dark: 0xF9FDF8)
    static let budgetPrimaryActionForeground = Color.budgetDynamic(light: 0xF9FDF8, dark: 0x10120F)
    static let budgetSecondaryActionBackground = Color.budgetDynamic(light: 0xE8ECE7, dark: 0x242724)
    static let budgetSecondaryActionForeground = Color.budgetDynamic(light: 0x3E413D, dark: 0xE8ECE7)

    static let budgetPositive = Color.budgetDynamic(light: 0x336D29, dark: 0x8DDC70)
    static let budgetWarning = Color.budgetWarm
    static let budgetNegative = Color.budgetOverBudget

    static let budgetPositiveFill = Color.budgetDynamic(light: 0xD6F1CE, dark: 0x1C4F14)
    static let budgetWarningFill = Color.budgetDynamic(light: 0xEDB345, dark: 0xEDB345).opacity(0.22)
    static let budgetNegativeFill = Color.budgetDynamic(light: 0xDB4241, dark: 0xDB4241).opacity(0.18)

    private init(hex: UInt, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    private static func budgetDynamic(light: UInt, dark: UInt) -> Color {
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
