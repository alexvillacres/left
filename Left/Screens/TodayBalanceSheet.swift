import SwiftUI

struct TodayBalanceSheet: View {
    let date: Date
    let allowance: Decimal
    let spent: Decimal
    let remaining: Decimal

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    // The hero is the source of truth, including prior-month carry and money
    // set aside. Resolve the display remainder at currency precision so the
    // three visible rows add up even when the daily rate has fractional cents.
    private var displayedAllowance: Decimal { allowance.rounded(scale: 2, mode: .bankers) }
    private var displayedSpent: Decimal { spent.rounded(scale: 2, mode: .bankers) }
    private var displayedRemaining: Decimal { remaining.rounded(scale: 2, mode: .bankers) }
    private var carriedForward: Decimal {
        displayedRemaining - displayedAllowance + displayedSpent
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    PlanSheetHeader(
                        title: "Your spending balance",
                        subtitle: date.formatted(.dateTime.weekday(.abbreviated).month(.wide).day().year())
                    )

                    VStack(spacing: AppSpacing.lg) {
                        balanceRow(isToday ? "Today’s allowance" : "Day’s allowance",
                                   amount: displayedAllowance)
                        balanceRow("Carried forward", amount: carriedForward, showsPlus: true)
                        balanceRow(isToday ? "Logged today" : "Logged that day", amount: -displayedSpent)
                        Divider()
                        balanceRow(isToday ? "Left to spend today" : "Left that day",
                                   amount: remaining, emphasized: true)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(balanceExplanation)
                            .font(.dmSans(.subheadline))
                            .foregroundStyle(.secondary)

                        Text("Based on your plan and logged spending. Bills and savings in Plan are already deducted; carried-forward money includes earlier days and months.")
                            .font(.dmSans(.footnote))
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.xxl)
                .padding(.bottom, AppSpacing.lg)
            }

            Button { dismiss() } label: {
                Text("Done")
                    .font(.dmSans(.body, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color(uiColor: .label), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(520), .large])
        .presentationDragIndicator(.visible)
    }

    private var balanceExplanation: String {
        if allowance < 0 {
            return "Your plan’s bills and savings exceed its income. Updating your plan changes the daily allowance."
        }
        if allowance == 0 {
            return "This date has no daily allowance. The balance reflects carried-forward money and logged spending."
        }
        if remaining < 0 {
            return "This balance carries forward. Future daily allowances bring it back up, and new spending reduces it."
        }
        return "Unspent money stays available for larger purchases. Spending beyond your balance uses future daily allowances."
    }

    private func balanceRow(_ title: String, amount: Decimal,
                            showsPlus: Bool = false, emphasized: Bool = false) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.lg) {
                Text(title)
                Spacer(minLength: AppSpacing.sm)
                signedAmount(amount, showsPlus: showsPlus)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                signedAmount(amount, showsPlus: showsPlus)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.dmSans(emphasized ? .title3 : .body, weight: emphasized ? .semibold : .regular))
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(amount.formatted(.currency(code: "USD")))")
    }

    private func signedAmount(_ amount: Decimal, showsPlus: Bool) -> some View {
        HStack(spacing: 0) {
            if showsPlus && amount > 0 { Text("+") }
            MoneyText(amount: amount)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
