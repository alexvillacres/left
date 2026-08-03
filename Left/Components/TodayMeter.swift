import SwiftUI

struct TodayMeter: View {
    let spent: Decimal
    let dailyRate: Decimal

    private let meterHeight: CGFloat = 56
    private let fillInset: CGFloat = 4
    private let minimumFillWidth: CGFloat = 8
    private let trackCornerRadius: CGFloat = 12
    private let fillCornerRadius: CGFloat = 8

    private var isOverspent: Bool {
        dailyRate > 0 && spent > dailyRate
    }

    private var spentFraction: CGFloat {
        guard dailyRate > 0 else { return spent > 0 ? 1 : 0 }

        let fraction = NSDecimalNumber(decimal: spent / dailyRate).doubleValue
        guard fraction.isFinite else { return 1 }
        return min(max(CGFloat(fraction), 0), 1)
    }

    private var remainingFraction: CGFloat {
        guard dailyRate > 0 else { return spent > 0 ? 0 : 1 }
        return 1 - spentFraction
    }

    // Move through the existing semantic palette as today's budget is used.
    // The final red overlay remains partially transparent over warning amber,
    // producing an orange-red nub just before the fill is fully depleted.
    private var warningOpacity: Double {
        min(Double(spentFraction) / 0.65, 1)
    }

    private var negativeOpacity: Double {
        max((Double(spentFraction) - 0.65) / 0.35, 0) * 0.65
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - fillInset * 2, 0)
            let fillWidth = remainingFraction > 0
                ? min(availableWidth, max(minimumFillWidth, availableWidth * remainingFraction))
                : 0

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous)
                    .fill(Color.neutral50)
                    .strokeBorder(Color.neutral100, lineWidth: 0.5)

                if isOverspent {
                    RoundedRectangle(cornerRadius: fillCornerRadius, style: .continuous)
                        .fill(Color.leftNegative.opacity(0.5))
                        .frame(width: availableWidth)
                        .padding(fillInset)
                } else if fillWidth > 0 {
                    ZStack {
                        RoundedRectangle(cornerRadius: fillCornerRadius, style: .continuous)
                            .fill(Color.fern300.opacity(0.5))
                        RoundedRectangle(cornerRadius: fillCornerRadius, style: .continuous)
                            .fill(Color.leftWarning)
                            .opacity(warningOpacity)
                        RoundedRectangle(cornerRadius: fillCornerRadius, style: .continuous)
                            .fill(Color.leftNegative)
                            .opacity(negativeOpacity)
                    }
                    .frame(width: fillWidth)
                    .padding(fillInset)
                }
            }
        }
        .frame(height: meterHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let budget = dailyRate.formatted(.currency(code: "USD"))
        if isOverspent {
            return "Today, over the \(budget) budget"
        }

        let amountSpent = spent.formatted(.currency(code: "USD"))
        return "Today, \(amountSpent) of \(budget) spent"
    }
}

#Preview {
    VStack(spacing: AppSpacing.xl) {
        TodayMeter(spent: 24, dailyRate: 68)
        TodayMeter(spent: 68, dailyRate: 68)
        TodayMeter(spent: 82, dailyRate: 68)
    }
    .padding(AppSpacing.xl)
}
