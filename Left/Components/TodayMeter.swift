import SwiftUI

enum BudgetState {
    static let nearLimitRemainingFraction: Decimal = 0.25

    case positive
    case warning
    case negative

    static func resolve(remaining: Decimal, dailyRate: Decimal) -> BudgetState {
        guard dailyRate > 0 else { return .positive }
        if remaining <= 0 { return .negative }
        if remaining <= dailyRate * nearLimitRemainingFraction { return .warning }
        return .positive
    }
}

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

    private var remaining: Decimal {
        dailyRate - spent
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

    private var budgetState: BudgetState {
        BudgetState.resolve(remaining: remaining, dailyRate: dailyRate)
    }

    private var fillColor: Color {
        budgetState == .warning ? .meterWarningFill : .meterFill
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - fillInset * 2, 0)
            let fillWidth = remainingFraction > 0
                ? min(availableWidth, max(minimumFillWidth, availableWidth * remainingFraction))
                : 0

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous)
                    .fill(Color.meterTrack)
                    .strokeBorder(Color.meterTrackBorder, lineWidth: 0.5)

                if isOverspent {
                    RoundedRectangle(cornerRadius: fillCornerRadius, style: .continuous)
                        .fill(Color.meterOverspentFill)
                        .frame(width: availableWidth)
                        .padding(fillInset)
                } else if fillWidth > 0 {
                    RoundedRectangle(cornerRadius: fillCornerRadius, style: .continuous)
                        .fill(fillColor)
                        .frame(width: fillWidth)
                        .padding(fillInset)
                }

                Text(meterLabel)
                    .font(.dmSans(.subheadline, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.md)
                    .contentTransition(.numericText())
            }
        }
        .frame(height: meterHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let budget = dailyRate.formatted(.currency(code: "USD"))
        if isOverspent {
            let amountOver = abs(remaining).formatted(.currency(code: "USD"))
            return "Today, \(amountOver) over the \(budget) budget"
        }

        let amounts = "Today, \(remaining.formatted(.currency(code: "USD"))) left of the \(budget) budget"
        return budgetState == .warning ? "\(amounts), near limit" : amounts
    }

    private var meterLabel: String {
        remaining.formatted(
            .currency(code: "USD")
                .precision(.fractionLength(0))
        )
    }
}

#Preview {
    VStack(spacing: AppSpacing.xl) {
        TodayMeter(spent: 24, dailyRate: 68)
        TodayMeter(spent: 55, dailyRate: 68)
        TodayMeter(spent: 68, dailyRate: 68)
        TodayMeter(spent: 82, dailyRate: 68)
    }
    .padding(AppSpacing.xl)
}
