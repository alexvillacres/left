import SwiftUI

/// The empty spending state for the selected day.
struct TodayEmptyState: View {
    let isToday: Bool
    let needsIncomeSetup: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sm) {
                Image("TodayEmptyState")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.leftAccent)
                    .frame(maxWidth: 288)
                    .accessibilityHidden(true)

                Text("No spending today")
                    .font(.dmSans(size: 16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(.primary)

                Text(isToday
                     ? (needsIncomeSetup
                        ? "Tap + to log spending."
                        : "Tap + to log spending. Unused allowance carries forward.")
                     : "There are no entries for this day.")
                    .font(.dmSans(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 250)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xxl * 2)
            .padding(.bottom, TodayView.addButtonSize + AppSpacing.xl * 2)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
