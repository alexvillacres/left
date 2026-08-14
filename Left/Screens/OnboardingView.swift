import SwiftUI

struct OnboardingView: View {
    let plan: MonthPlan
    var onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettingUpMonth = false
    @ScaledMetric private var heroSize: CGFloat = 44

    var body: some View {
        Group {
            if isSettingUpMonth {
                PlanView(plan: plan, isOnboarding: true, onComplete: onComplete)
                    .transition(.opacity)
            } else {
                intro
                    .transition(.opacity)
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .interactiveDismissDisabled()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var intro: some View {
        VStack(spacing: 0) {
            Spacer(minLength: AppSpacing.xl)

            VStack(spacing: AppSpacing.xxl) {
                VStack(spacing: AppSpacing.md) {
                    Text("One number.")
                        .font(.dmSans(size: BudgetTypography.headingSize, weight: .bold, relativeTo: .title2))
                        .tracking(BudgetTypography.headingTracking)
                        .foregroundStyle(.primary)

                    Text("Left takes what you earn, subtracts what's fixed and what you're saving, and shows what you can spend today; log what you spend, that's it.")
                        .font(.dmSans(.body))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 320)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                Text("$——")
                    .font(.dmSans(size: heroSize, weight: .semibold, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.xl)

            Spacer(minLength: AppSpacing.xl)

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                    isSettingUpMonth = true
                }
            } label: {
                Text("Set up your month")
                    .font(.dmSans(.body, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)
        }
    }
}

#Preview {
    OnboardingView(
        plan: MonthPlan(monthStart: .now, monthlyIncome: 0, savingsGoal: 0),
        onComplete: {}
    )
    .environment(\.font, .dmSans(.body))
    .tracking(BudgetTypography.appTracking)
    .tint(.leftAccent)
}
