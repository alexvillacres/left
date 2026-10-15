import SwiftUI

// A proportional explanation of the plan. Draft overrides let the income and
// recurring-expense sheets preview their unsaved values without mutating the
// model; percentage savings are resolved against the effective draft income.
struct DerivationBar: View {
    let plan: MonthPlan
    var income: Decimal? = nil
    var fixedTotal: Decimal? = nil
    var showsDetails = true
    // Just the proportional meter, for the Plan summary where the rows below
    // already name each part.
    var isMeterOnly = false

    @State private var isShowingDetails = false

    private var meterHeight: CGFloat { isMeterOnly ? 44 : 56 }
    private var meterInset: CGFloat { isMeterOnly ? 6 : 4 }
    private var segmentRadius: CGFloat { isMeterOnly ? 10 : 8 }
    private let segmentSpacing: CGFloat = 4
    private let minimumSegmentWidth: CGFloat = 8

    private var effectiveIncome: Decimal { income ?? plan.incomeTotal }
    private var effectiveFixedTotal: Decimal { fixedTotal ?? plan.fixedTotal }
    private var savings: Decimal { plan.savingsAmount(for: effectiveIncome) }
    private var spendable: Decimal { effectiveIncome - effectiveFixedTotal - savings }
    private var days: Int { plan.daysInMonth() }
    private var dailyRate: Decimal { spendable / Decimal(days) }
    private var needsIncomeSetup: Bool { income == nil && plan.needsIncomeSetup }

    private var wholeDollars: Decimal.FormatStyle.Currency {
        .init(code: "USD").precision(.fractionLength(0))
    }

    private var dailyDollars: Decimal.FormatStyle.Currency {
        .init(code: "USD").precision(.fractionLength(2))
    }

    var body: some View {
        Group {
            if needsIncomeSetup {
                Text("Set \(plan.monthStart.formatted(.dateTime.month(.wide))) income to calculate your daily allowance.")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isMeterOnly {
                meter
            } else if showsDetails {
                Button {
                    isShowingDetails = true
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(needsIncomeSetup ? "Set monthly income to calculate your daily allowance" : accessibilitySummary)
        .accessibilityAddTraits(showsDetails && !needsIncomeSetup ? .isButton : [])
        .sheet(isPresented: $isShowingDetails) {
            derivationDetails
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.leftBackground)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            meter
            legend

            Text("That leaves \(dailyRate.formatted(dailyDollars)) per day for \(days) days")
                .font(.dmSans(.subheadline, weight: .bold))
                .foregroundStyle(spendable > 0 ? Color.leftPlanSpendableText : Color.leftFeedbackNegative)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var meter: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - meterInset * 2, 0)

            ZStack {
                RoundedRectangle(cornerRadius: isMeterOnly ? 16 : 12, style: .continuous)
                    .fill(Color.leftNeutralFill)

                if effectiveIncome > 0, spendable <= 0 {
                    RoundedRectangle(cornerRadius: segmentRadius, style: .continuous)
                        .fill(Color.leftFeedbackOverspentBg)
                        .padding(meterInset)
                } else if effectiveIncome > 0 {
                    let widths = segmentWidths(availableWidth: availableWidth)
                    HStack(spacing: segmentSpacing) {
                        if effectiveFixedTotal > 0 {
                            segment(width: widths.fixed,
                                    fill: Color.leftPlanExpenses)
                        }
                        if savings > 0 {
                            segment(width: widths.savings,
                                    fill: Color.leftPlanSavings)
                        }
                        if spendable > 0 {
                            segment(width: widths.spendable,
                                    fill: Color.leftPlanSpendable)
                        }
                    }
                    .padding(meterInset)
                }
            }
        }
        .frame(height: meterHeight)
    }

    private func segment(width: CGFloat, fill: Color) -> some View {
        RoundedRectangle(cornerRadius: segmentRadius, style: .continuous)
            .fill(fill)
            .frame(width: width)
    }

    private var legend: some View {
        HStack(spacing: AppSpacing.sm) {
            legendItem("Income", color: Color.leftNeutralFill)
            legendItem("Fixed", color: Color.leftPlanExpenses)
            legendItem("Savings", color: Color.leftPlanSavings)
            legendItem("Spendable", color: Color.leftPlanSpendable)
            Spacer(minLength: 0)
            if showsDetails {
                Image(systemName: "info.circle")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.dmSans(.caption))
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).lineLimit(1)
        }
    }

    private var derivationDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            PlanSheetHeader(
                title: "Your daily amount",
                subtitle: "How \(plan.monthStart.formatted(.dateTime.month(.wide).year())) income is divided"
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                detailRow("Income", value: effectiveIncome, color: Color.leftNeutralFill)
                detailRow("Fixed expenses", value: effectiveFixedTotal, color: Color.leftPlanExpenses, prefix: "−")
                detailRow("Savings", value: savings, color: Color.leftPlanSavings, prefix: "−")
                Divider()
                detailRow("Spendable", value: spendable,
                          color: spendable > 0 ? Color.leftPlanSpendable : Color.leftFeedbackNegative)

                HStack {
                    Text("Days in \(plan.monthStart.formatted(.dateTime.month(.wide)))")
                    Spacer()
                    Text("÷ \(days)")
                        .monospacedDigit()
                }
                .font(.dmSans(.subheadline))
                .foregroundStyle(.secondary)

                Text("That leaves \(dailyRate.formatted(dailyDollars)) per day")
                    .font(.dmSans(.title3, weight: .bold))
                    .foregroundStyle(spendable > 0 ? Color.leftPlanSpendableText : Color.leftFeedbackNegative)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.xl)
        .padding(.bottom, AppSpacing.lg)
        .background(Color.leftBackground.ignoresSafeArea())
    }

    private func detailRow(_ title: String,
                           value: Decimal,
                           color: Color,
                           prefix: String? = nil) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title)
            Spacer()
            Text("\(prefix.map { "\($0) " } ?? "")\(value.formatted(wholeDollars))")
                .monospacedDigit()
        }
        .font(.dmSans(.body))
    }

    private func segmentWidths(availableWidth: CGFloat) -> (fixed: CGFloat, savings: CGFloat, spendable: CGFloat) {
        let values = [effectiveFixedTotal, savings, max(0, spendable)].map { max(0, $0) }
        let visibleCount = values.filter { $0 > 0 }.count
        let contentWidth = max(availableWidth - CGFloat(max(visibleCount - 1, 0)) * segmentSpacing, 0)
        guard effectiveIncome > 0, contentWidth > 0 else { return (0, 0, 0) }

        var widths = values.map {
            $0 > 0 ? contentWidth * CGFloat(NSDecimalNumber(decimal: $0 / effectiveIncome).doubleValue) : 0
        }
        for index in widths.indices where values[index] > 0 && widths[index] < minimumSegmentWidth {
            let needed = minimumSegmentWidth - widths[index]
            if let donor = widths.indices
                .filter({ $0 != index })
                .max(by: { widths[$0] < widths[$1] }) {
                let donated = min(needed, max(0, widths[donor] - minimumSegmentWidth))
                widths[index] += donated
                widths[donor] -= donated
            }
        }
        return (widths[0], widths[1], widths[2])
    }

    private var accessibilitySummary: String {
        "Income \(effectiveIncome.formatted(wholeDollars)), minus fixed expenses \(effectiveFixedTotal.formatted(wholeDollars)), minus savings \(savingsTerm), leaves \(spendable.formatted(wholeDollars)) across \(days) days, or \(dailyRate.formatted(dailyDollars)) per day."
    }

    private var savingsTerm: String {
        if plan.savingsGoals.isEmpty, let percent = plan.savingsPercent {
            return "\(percent.formatted(.number)) percent, \(savings.formatted(wholeDollars))"
        }
        if plan.savingsGoals.count == 1, let percent = plan.savingsGoals.first?.percent {
            return "\(percent.formatted(.number)) percent, \(savings.formatted(wholeDollars))"
        }
        return savings.formatted(wholeDollars)
    }
}
