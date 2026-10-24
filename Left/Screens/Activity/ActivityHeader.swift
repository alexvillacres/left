import SwiftUI

/// Activity’s month picker and total, composed with the shared header chrome.
struct ActivityHeader: View {
    let plan: MonthPlan?
    let plans: [MonthPlan]
    let total: Decimal
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onSelect: (MonthPlan) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let heroSize: CGFloat = 44

    var body: some View {
        ScreenHeader {
            header(plan)

            if plan != nil {
                ScreenHeadlineSlot {
                    monthTotal(total: total)
                }
            }
        }
    }

    // The month names what the total and the list below are describing.
    @ViewBuilder
    private func header(_ plan: MonthPlan?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let plan {
                PeriodNavigationRow(
                    stepper: PeriodStepper(previousLabel: "Previous month",
                                           nextLabel: "Next month",
                                           canGoPrevious: canGoPrevious,
                                           canGoNext: canGoNext,
                                           onPrevious: onPrevious,
                                           onNext: onNext)
                ) {
                    PeriodPill(
                        label: plan.monthStart.formatted(.dateTime.month(.abbreviated).year()),
                        isEnabled: plans.count > 1,
                        cornerRadius: AppSpacing.xs,
                        accessibilityLabel: "Month, \(plan.monthStart.formatted(.dateTime.month(.wide).year()))",
                        accessibilityHint: "Choose another month"
                    ) {
                        ForEach(plans) { candidate in
                            Button {
                                onSelect(candidate)
                            } label: {
                                if candidate.monthStart == plan.monthStart {
                                    Label(candidate.monthStart.formatted(.dateTime.month(.wide).year()),
                                          image: "IconCheckmark")
                                } else {
                                    Text(candidate.monthStart, format: .dateTime.month(.wide).year())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func monthTotal(total: Decimal) -> some View {
        HeroMoneyText(amount: total, size: heroSize, weight: .medium,
                      suffix: "spent", suffixColor: .leftTextTertiary,
                      suffixSizeRatio: 2.0 / 3.0)
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: total)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            .accessibilityElement(children: .combine)
    }
}
