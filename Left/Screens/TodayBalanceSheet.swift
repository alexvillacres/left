import SwiftUI

/// The expanded, inline explanation beneath Today's balance.
struct TodayBalanceSheet: View {
    let day: BalanceDay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isToday: Bool { Calendar.current.isDateInToday(day.date) }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            step("Carried forward", amount: day.carriedForward)
            step(isToday ? "Today’s allowance" : "Day’s allowance",
                 amount: day.displayedAllowance, showsPlus: true)
            step(isToday ? "Logged today" : "Logged that day", amount: -day.displayedSpent)
            Rectangle().fill(Color.leftDivider).frame(height: 1)
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                if day.isOver {
                    Circle().fill(Color.leftFeedbackNegative)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
                Text(day.explanation)
                    .font(.dmSans(.footnote))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color.leftTextSecondary)
        .padding(AppSpacing.lg)
        .background(Color.leftNeutralFill.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    private func step(_ title: String, amount: Decimal, showsPlus: Bool = false) -> some View {
        AdaptiveValuePair {
            Text(title)
        } value: {
            HStack(spacing: 0) {
                if showsPlus && amount > 0 { Text("+") }
                MoneyText(amount: amount)
            }
            .foregroundStyle(Color.leftTextPrimary)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: amount)
            .fixedSize(horizontal: true, vertical: false)
        }
        .font(.dmSans(.subheadline))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(amount.formatted(.currency(code: "USD")))")
    }
}
