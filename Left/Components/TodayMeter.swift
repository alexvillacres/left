import SwiftUI

struct TodayMeter: View {
    let spent: Decimal
    let dailyRate: Decimal

    private let meterHeight: CGFloat = 14
    private let minimumFillWidth: CGFloat = 8

    private var isOverspent: Bool {
        dailyRate > 0 && spent > dailyRate
    }

    private var remainingFraction: CGFloat {
        guard dailyRate > 0 else { return spent > 0 ? 0 : 1 }

        let spentFraction = NSDecimalNumber(decimal: spent / dailyRate).doubleValue
        guard spentFraction.isFinite else { return 0 }
        return 1 - min(max(CGFloat(spentFraction), 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let fillWidth = remainingFraction > 0
                ? min(geometry.size.width, max(minimumFillWidth, geometry.size.width * remainingFraction))
                : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        isOverspent
                            ? Color.leftNegative.opacity(0.35)
                            : Color.fern100.opacity(0.5)
                    )

                if !isOverspent, fillWidth > 0 {
                    Capsule()
                        .fill(Color.fern300)
                        .frame(width: fillWidth)
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
