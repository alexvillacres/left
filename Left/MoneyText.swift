import SwiftUI

// MARK: - Shared currency display

struct MoneyText: View {
    let amount: Decimal

    var body: some View {
        Text(amount, format: .currency(code: "USD"))
            .monospacedDigit()
    }
}

// MARK: - Large display amount

/// Hero-sized amount with tight tracking. Steps down through fixed sizes via
/// ViewThatFits instead of minimumScaleFactor — combining tracking with
/// minimumScaleFactor makes SwiftUI clip the outer glyphs.
struct HeroMoneyText: View {
    let amount: Decimal
    var size: CGFloat = 56

    private static let scales: [CGFloat] = [1, 0.85, 0.7, 0.55]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Self.scales, id: \.self) { scale in
                styledText(pointSize: size * scale)
            }
        }
    }

    private func styledText(pointSize: CGFloat) -> some View {
        Text(amount, format: .currency(code: "USD"))
            .font(.figtree(size: pointSize, weight: .semibold, relativeTo: .largeTitle))
            .tracking(pointSize * -0.04)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }
}
