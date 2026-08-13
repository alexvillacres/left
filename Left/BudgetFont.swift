import SwiftUI

enum BudgetTypography {
    static let headingSize: CGFloat = 24
    static let bodySize: CGFloat = 17
    static let letterSpacingPercent: CGFloat = -0.02

    static func tracking(for pointSize: CGFloat) -> CGFloat {
        pointSize * letterSpacingPercent
    }

    static let appTracking = tracking(for: bodySize)
    static let headingTracking = tracking(for: headingSize)
}

extension Font {
    static func dmSans(_ textStyle: TextStyle, weight: Weight = .regular) -> Font {
        .custom(dmSansName(for: weight), size: defaultSize(for: textStyle), relativeTo: textStyle)
    }

    static func dmSans(size: CGFloat, weight: Weight = .regular, relativeTo textStyle: TextStyle = .body) -> Font {
        .custom(dmSansName(for: weight), size: size, relativeTo: textStyle)
    }

    private static func dmSansName(for weight: Weight) -> String {
        switch weight {
        case .medium:
            return "DMSans-Medium"
        case .semibold, .bold, .heavy, .black:
            return "DMSans-Bold"
        default:
            return "DMSans-Regular"
        }
    }

    private static func defaultSize(for textStyle: TextStyle) -> CGFloat {
        switch textStyle {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}
