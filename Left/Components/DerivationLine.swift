import SwiftUI

// The line that makes the daily number trustworthy: every term that went into
// it, in order, ending on the rate itself.
//
// `income` lets a caller preview a value the plan doesn't hold yet — the income
// sheet types against it live — without mutating anything. Savings and spendable
// are recomputed from that draft rather than read off the plan, so a percentage
// target moves with the number under your thumb.
struct DerivationLine: View {
    let plan: MonthPlan
    var income: Decimal? = nil

    private var effectiveIncome: Decimal { income ?? plan.monthlyIncome }

    private var savings: Decimal {
        if let percent = plan.savingsPercent {
            (effectiveIncome * percent / 100).roundedToCents()
        } else {
            max(0, plan.savingsGoal)
        }
    }

    private var spendable: Decimal { effectiveIncome - plan.fixedTotal - savings }

    private var dailyRate: Decimal { spendable / Decimal(plan.daysInMonth()) }

    private var money: Decimal.FormatStyle.Currency {
        .init(code: "USD").precision(.fractionLength(0))
    }

    private var savingsTerm: String {
        if let percent = plan.savingsPercent {
            "\(percent.formatted(.number))% (\(savings.formatted(money)))"
        } else {
            savings.formatted(money)
        }
    }

    private var rateString: String { "\(dailyRate.formatted(money))/day" }

    var body: some View {
        let lead = "\(effectiveIncome.formatted(money)) − \(plan.fixedTotal.formatted(money)) − \(savingsTerm) = \(spendable.formatted(money)) ÷ \(plan.daysInMonth()) days = "

        let rateText = Text(rateString)
            .font(.dmSans(.subheadline, weight: .bold))
            .foregroundStyle(spendable > 0 ? Color.leftPositive : Color.leftNegative)

        Text("\(Text(lead).foregroundStyle(.secondary))\(rateText)")
            .font(.dmSans(.subheadline))
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Money available \(effectiveIncome.formatted(money)), minus recurring expenses \(plan.fixedTotal.formatted(money)), minus savings \(savingsTerm), leaves \(spendable.formatted(money)) across \(plan.daysInMonth()) days, or \(rateString).")
    }
}
