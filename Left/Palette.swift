import SwiftUI
import UIKit

extension Color {
    static let fern100 = Color(hex: 0xD6F1CE)
    static let fern300 = Color(hex: 0x8DDC70)
    static let fern500 = Color(hex: 0x509341)
    static let fern700 = Color(hex: 0x1C4F14)
    static let neutral50 = Color(hex: 0xF5F5F5)
    static let neutral100 = Color(hex: 0xEBEBEB)

    static let leftPositive = Color.dynamic(light: 0x336D29, dark: 0x8DDC70)
    static let leftWarning = Color.dynamic(light: 0xA8730F, dark: 0xEDB345)
    static let leftNegative = Color.dynamic(light: 0xC63735, dark: 0xE4605E)

    private init(hex: UInt, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

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
