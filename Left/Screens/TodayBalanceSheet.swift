import SwiftUI

struct TodayBalanceSheet: View {
    let date: Date
    let allowance: Decimal
    let spent: Decimal
    let remaining: Decimal
    let entryCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Drops each dot onto the first line of its step as text scales.
    @ScaledMetric(relativeTo: .body) private var dotInset: CGFloat = 5
    @ScaledMetric(relativeTo: .body) private var dotSize: CGFloat = 12

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    // The hero is the source of truth, including prior-month carry and money
    // set aside. Resolve the display remainder at currency precision so the
    // visible steps add up even when the daily rate has fractional cents.
    private var displayedAllowance: Decimal { allowance.rounded(scale: 2, mode: .bankers) }
    private var displayedSpent: Decimal { spent.rounded(scale: 2, mode: .bankers) }
    private var displayedRemaining: Decimal { remaining.rounded(scale: 2, mode: .bankers) }
    private var carriedForward: Decimal {
        displayedRemaining - displayedAllowance + displayedSpent
    }

    var body: some View {
        // The balance stays in Today's header. These three steps explain it
        // directly on the same ground, above the spending container.
        VStack(spacing: 0) {
            step(carriedForward >= 0 ? "Carried forward" : "Over from earlier days",
                 amount: carriedForward,
                 detail: carriedDetail,
                 dot: carriedForward > 0 ? .filled(.leftGroundTodayTextSecondary)
                    : carriedForward < 0 ? .filled(.leftFeedbackNegative) : .hollow)
            step(isToday ? "Today’s allowance" : "Day’s allowance",
                 amount: displayedAllowance,
                 showsPlus: true,
                 detail: allowanceDetail,
                 dot: displayedAllowance > 0 ? .filled(.leftGroundTodayTextSecondary)
                    : displayedAllowance < 0 ? .filled(.leftFeedbackNegative) : .hollow)
            step(isToday ? "Logged today" : "Logged that day",
                 amount: -displayedSpent,
                 detail: entryDetail,
                 dot: .hollow,
                 continues: false)
        }
        .foregroundStyle(Color.leftGroundTextPrimary, Color.leftGroundTodayTextSecondary)
        .environment(\.colorScheme, .light)
    }

    // MARK: - Copy

    private var carriedDetail: String {
        if carriedForward > 0 { return "Unspent from earlier days" }
        if carriedForward < 0 { return "Spent beyond earlier allowances" }
        return "Nothing carried in"
    }

    private var allowanceDetail: String {
        if allowance < 0 { return "Your plan’s recurring expenses and savings exceed its income" }
        if allowance == 0 { return "No daily allowance on this date" }
        return "From your plan"
    }

    private var entryDetail: String {
        switch entryCount {
        case 0: "No entries"
        case 1: "1 entry"
        default: "\(entryCount) entries"
        }
    }

    // MARK: - Steps

    private enum Dot {
        case filled(Color)
        case hollow
    }

    private func step(_ title: String, amount: Decimal, showsPlus: Bool = false,
                      detail: String, dot: Dot, continues: Bool = true) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.lg) {
            rail(dot, inset: dotInset, continues: continues)

            VStack(alignment: .leading, spacing: 2) {
                amountLine(title: title, amount: amount, showsPlus: showsPlus)
                    .font(.dmSans(.body))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.dmSans(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, continues ? AppSpacing.xl : 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(amount.formatted(.currency(code: "USD"))), \(detail)")
    }

    private func rail(_ dot: Dot, inset: CGFloat, continues: Bool) -> some View {
        VStack(spacing: 0) {
            Group {
                switch dot {
                case .filled(let color):
                    Circle().fill(color)
                case .hollow:
                    Circle().strokeBorder(Color.leftGroundTodayTextSecondary, lineWidth: 2)
                }
            }
            .frame(width: dotSize, height: dotSize)

            if continues {
                Rectangle()
                    .fill(Color.leftReportButterPerforation)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(.top, inset)
        .accessibilityHidden(true)
    }

    private func amountLine(title: String, amount: Decimal, showsPlus: Bool) -> some View {
        AdaptiveValuePair {
            Text(title)
        } value: {
            signedAmount(amount, showsPlus: showsPlus)
        }
    }

    private func signedAmount(_ amount: Decimal, showsPlus: Bool) -> some View {
        HStack(spacing: 0) {
            if showsPlus && amount > 0 { Text("+") }
            MoneyText(amount: amount)
        }
        .contentTransition(.numericText())
        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: amount)
        .fixedSize(horizontal: true, vertical: false)
    }
}
