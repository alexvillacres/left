import SwiftUI

// Seven day meters. Each column is an identical track representing that
// day's budget (the daily rate); the fill is what was actually spent.
// Headroom left in the track is money kept. An overspent day fills the
// whole track in a muted red — clear, but quiet. The fixed scale means
// the strip never re-scales itself as values change.

struct SpendingDay {
    let date: Date
    let spent: Decimal
    let dailyRate: Decimal
    let isSelected: Bool
    let isAvailable: Bool

    var isOverBudget: Bool {
        isAvailable && spent > 0 && spent > dailyRate
    }

    // Share of the day's budget that was spent, clamped to 0...1.
    var fillFraction: Decimal {
        guard dailyRate > 0 else { return spent > 0 ? 1 : 0 }
        return min(spent / dailyRate, 1)
    }
}

struct SpendingWeekStrip: View {
    let days: [SpendingDay]

    private let trackHeight: CGFloat = 80
    private let cornerRadius: CGFloat = 12
    private let fillInset: CGFloat = 4
    private let minimumFillHeight: CGFloat = 8

    // Smallest fill that can contain the amount label. Scales with
    // Dynamic Type so the fits-inside check stays honest at any size.
    @ScaledMetric(relativeTo: .caption2) private var labelAllowance: CGFloat = 32

    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
            // Columns are identified by slot, not by date: a day swipe morphs
            // each meter in place. Date identity would make surviving columns
            // slide while the edge columns crossfade under them, leaving the
            // amount labels ghosting behind the moving bars.
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                column(day)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Columns

    private func column(_ day: SpendingDay) -> some View {
        let fillHeight = fillHeight(for: day)

        return VStack(spacing: AppSpacing.xs) {
            ZStack(alignment: .bottom) {
                track(day)
                if day.isAvailable && day.spent > 0 {
                    fill(
                        day,
                        height: day.isOverBudget ? trackHeight : fillHeight
                    )
                    .padding(.horizontal, day.isOverBudget ? 0 : fillInset)
                    .padding(.bottom, day.isOverBudget ? 0 : fillInset)
                }
            }
            .frame(height: trackHeight)
            .overlay(alignment: .bottom) {
                amountLabel(day, fillHeight: fillHeight)
            }

            Text(day.date, format: .dateTime.weekday(.narrow))
                .contentTransition(.opacity)
                .font(.dmSans(.caption2, weight: day.isSelected ? .semibold : .regular))
                .foregroundStyle(day.isSelected ? Color.primary : Color.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // Fern-100 track: the headroom reads as money kept. An overspent
    // day has no headroom, so its track goes clear and only the red
    // fill shows — a green frame around red would suggest headroom.
    private func track(_ day: SpendingDay) -> some View {
        let color: Color = day.isOverBudget
            ? .clear
        : .fern100.opacity(day.isAvailable ? 0.5 : 0.15)

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color)
    }

    // In-budget fill floats inside the track. An over-budget fill uses
    // the full track bounds so every visible column has the same width.
    // The corner radius never exceeds half the fill's height.
    private func fill(_ day: SpendingDay, height: CGFloat) -> some View {
        let color: Color = day.isOverBudget
            ? .leftNegative.opacity(day.isSelected ? 0.45 : 0.30)
            : .fern300.opacity(day.isSelected ? 1 : 0.5)
        let radius = min(
            day.isOverBudget ? cornerRadius : cornerRadius - fillInset,
            height / 2
        )

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(color)
            .frame(height: height)
    }

    private func fillHeight(for day: SpendingDay) -> CGFloat {
        let innerHeight = trackHeight - fillInset * 2
        return max(minimumFillHeight, innerHeight * clamped(day.fillFraction))
    }

    // Inside the fill when it fits; perched just above it when it
    // doesn't. The perch is clamped so the label can never leave the
    // track, even at accessibility text sizes.
    @ViewBuilder
    private func amountLabel(_ day: SpendingDay, fillHeight: CGFloat) -> some View {
        if day.isAvailable && day.spent > 0 {
            let fitsInside = fillHeight >= labelAllowance
            let bottomPadding = fitsInside
                ? AppSpacing.sm
                : min(fillInset + fillHeight + AppSpacing.xs, trackHeight - labelAllowance)

            MoneyText(amount: day.spent, showsCents: false)
                .font(.dmSans(.caption2, weight: .semibold))
                .contentTransition(.numericText(value: NSDecimalNumber(decimal: day.spent).doubleValue))
                .foregroundStyle(
                    day.isOverBudget
                        ? Color.leftNegative
                        : Color.fern700.opacity(day.isSelected ? 1 : 0.45)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, AppSpacing.xxs)
                .padding(.bottom, bottomPadding)
        }
    }

    // MARK: - Helpers

    private func clamped(_ value: Decimal) -> CGFloat {
        let value = CGFloat(NSDecimalNumber(decimal: value).doubleValue)
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    private var accessibilityLabel: String {
        let summaries = days.filter(\.isAvailable).map { day in
            let date = day.date.formatted(.dateTime.weekday(.wide))
            let spent = day.spent.formatted(.currency(code: "USD"))
            let budget = day.dailyRate.formatted(.currency(code: "USD"))
            return day.isOverBudget
                ? "\(date), spent \(spent), over the \(budget) budget"
                : "\(date), spent \(spent) of \(budget)"
        }
        return "Seven day spending. " + summaries.joined(separator: ". ")
    }
}

// MARK: - Derivation

extension MonthPlan {
    static func spendingWeek(
        from plans: [MonthPlan],
        around selectedDate: Date,
        fallbackPlan: MonthPlan,
        calendar: Calendar = .current
    ) -> [SpendingDay] {
        let selectedStart = calendar.startOfDay(for: selectedDate)

        return (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: selectedStart) else {
                return nil
            }

            let matchingPlan = plans.first {
                calendar.isDate($0.monthStart, equalTo: date, toGranularity: .month)
            }
            let canUseFallback = calendar.isDate(
                fallbackPlan.monthStart,
                equalTo: date,
                toGranularity: .month
            )
            let dayPlan = matchingPlan ?? (canUseFallback ? fallbackPlan : nil)

            guard let dayPlan else {
                return SpendingDay(
                    date: date,
                    spent: 0,
                    dailyRate: 0,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedStart),
                    isAvailable: false
                )
            }

            let spentOnDay = dayPlan.transactions
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amount }

            return SpendingDay(
                date: date,
                spent: spentOnDay,
                dailyRate: dayPlan.dailyRate,
                isSelected: calendar.isDate(date, inSameDayAs: selectedStart),
                isAvailable: true
            )
        }
    }
}

#Preview {
    let cal = Calendar.current
    let start = cal.leftMonthStart(for: .now)
    let plan = MonthPlan(monthStart: start, monthlyIncome: 6200, savingsGoal: 1000)
    plan.fixedExpenses = [FixedExpense(name: "Rent", amount: 1800)]
    plan.transactions = (0..<6).map {
        Transaction(
            amount: [82, 140, 0, 36, 12, 21][$0],
            date: cal.date(byAdding: .day, value: $0 - 5, to: .now)!,
            category: .food
        )
    }
    let days = MonthPlan.spendingWeek(from: [plan], around: .now, fallbackPlan: plan)

    return SpendingWeekStrip(days: days)
        .padding(AppSpacing.xl)
}
