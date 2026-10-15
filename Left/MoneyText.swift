import SwiftUI

// MARK: - Shared currency display

struct MoneyText: View {
    let amount: Decimal
    var showsCents = true

    var body: some View {
        Group {
            if showsCents {
                Text(amount, format: .currency(code: "USD"))
            } else {
                Text(
                    amount,
                    format: .currency(code: "USD")
                        .precision(.fractionLength(0))
                )
            }
        }
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
    var suffix: String? = nil
    var showsCents = true

    private static let scales: [CGFloat] = [1, 0.85, 0.7, 0.55]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Self.scales, id: \.self) { scale in
                styledText(pointSize: size * scale)
            }
            // The last candidate must accept the available width, even for
            // accessibility text sizes or unusually long amounts.
            label
                .font(.dmSans(size: size * Self.scales.last!, weight: .semibold, relativeTo: .largeTitle))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func styledText(pointSize: CGFloat) -> some View {
        label
            .font(.dmSans(size: pointSize, weight: .semibold, relativeTo: .largeTitle))
            .tracking(BudgetTypography.tracking(for: pointSize))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    private var label: Text {
        let format = showsCents
            ? Decimal.FormatStyle.Currency(code: "USD")
            : Decimal.FormatStyle.Currency(code: "USD").precision(.fractionLength(0))
        guard let suffix else {
            return Text(amount, format: format)
        }
        return Text("\(amount, format: format) \(suffix)")
    }
}
