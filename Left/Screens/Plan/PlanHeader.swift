import SwiftUI

/// Plan’s month navigation and headline within the shared main-screen header.
struct PlanHeader: View {
    let plan: MonthPlan
    let plans: [MonthPlan]
    let canEdit: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onSelect: (Date) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let heroSize: CGFloat = 44

    var body: some View {
        ScreenHeader {
            PeriodNavigationRow(
                stepper: PeriodStepper(previousLabel: "Previous plan",
                                       nextLabel: "Next plan",
                                       canGoPrevious: canGoPrevious,
                                       canGoNext: canGoNext,
                                       onPrevious: onPrevious,
                                       onNext: onNext)
            ) {
                PeriodPill(
                    label: plan.monthStart.formatted(.dateTime.month(.wide).year()),
                    isEnabled: true,
                    cornerRadius: AppSpacing.xs,
                    accessibilityLabel: "Plan month, \(plan.monthStart.formatted(.dateTime.month(.wide).year()))",
                    accessibilityHint: "Choose a plan month or open Settings"
                ) {
                    ForEach(plans.reversed()) { candidate in
                        Button {
                            onSelect(candidate.monthStart)
                        } label: {
                            if candidate.monthStart == plan.monthStart {
                                Label(candidate.monthStart.formatted(.dateTime.month(.wide).year()),
                                      systemImage: "checkmark")
                            } else {
                                Text(candidate.monthStart, format: .dateTime.month(.wide).year())
                            }
                        }
                    }
                    Divider()
                    Button("Settings", systemImage: "gearshape", action: onSettings)
                }
            }

            ScreenHeadlineSlot {
                VStack(spacing: AppSpacing.sm) {
                    HeroMoneyText(amount: plan.monthlySpendable, size: heroSize, weight: .medium,
                                  suffix: "to spend", suffixColor: .leftTextTertiary,
                                  suffixSizeRatio: 2.0 / 3.0)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: plan.monthlySpendable)
                        .frame(maxWidth: .infinity, minHeight: 44)

                    if let caption {
                        Text(caption)
                            .font(.dmSansSupporting(weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var caption: String? {
        guard canEdit else { return "Past plan · Read only" }
        guard !plan.needsIncomeSetup else { return "Add income to see your allowance" }
        return nil
    }
}
