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
    var weight: Font.Weight = .semibold
    var suffix: String? = nil
    var showsCents = true
    var suffixColor: Color? = nil
    var suffixSizeRatio: CGFloat? = nil

    private static let scales: [CGFloat] = [1, 0.85, 0.7, 0.55]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Self.scales, id: \.self) { scale in
                styledText(pointSize: size * scale)
            }
            // The last candidate must accept the available width, even for
            // accessibility text sizes or unusually long amounts.
            label(pointSize: size * Self.scales.last!)
                .font(.dmSans(size: size * Self.scales.last!, weight: weight, relativeTo: .largeTitle))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func styledText(pointSize: CGFloat) -> some View {
        label(pointSize: pointSize)
            .font(.dmSans(size: pointSize, weight: weight, relativeTo: .largeTitle))
            .tracking(BudgetTypography.tracking(for: pointSize))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    private func label(pointSize: CGFloat) -> Text {
        let format = showsCents
            ? Decimal.FormatStyle.Currency(code: "USD")
            : Decimal.FormatStyle.Currency(code: "USD").precision(.fractionLength(0))
        guard let suffix else {
            return Text(amount, format: format)
        }
        let suffixText = Text(" \(suffix)").foregroundColor(suffixColor)
        if let suffixSizeRatio {
            return Text(amount, format: format)
                + suffixText.font(.dmSans(size: pointSize * suffixSizeRatio, relativeTo: .largeTitle))
        }
        return Text(amount, format: format) + suffixText
    }
}
