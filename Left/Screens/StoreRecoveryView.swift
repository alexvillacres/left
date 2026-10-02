import SwiftUI

// The only screen that exists for a failure. Tone matches the rest of the app:
// it states what happened and what can be done, and it does not apologize or
// alarm. "Start over" is the honest name for what that button does — it is the
// same outcome as deleting the app, reachable without leaving it.
struct StoreRecoveryView: View {
    let error: Error
    let retry: () -> Void
    let reset: () -> Void

    @State private var isConfirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Spacer()

            Text("Left can't open your data")
                .font(.dmSans(size: BudgetTypography.headingSize, weight: .bold, relativeTo: .title2))
                .tracking(BudgetTypography.headingTracking)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Trying again is usually enough. If it keeps failing, you can start over with a fresh plan — that erases everything Left has stored on this device, and it can't be undone.")
                .font(.dmSans(.body))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Kept visible rather than logged: on TestFlight this is the only
            // detail a tester can actually hand back to you.
            Text(error.localizedDescription)
                .font(.dmSans(.caption))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppSpacing.xs)

            Spacer()

            Button(action: retry) {
                Text("Try again")
                    .font(.dmSans(.body, weight: .semibold))
                    .foregroundStyle(Color.leftBackground)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                isConfirmingReset = true
            } label: {
                Text("Start over")
                    .font(.dmSans(.body, weight: .medium))
                    .foregroundStyle(Color.leftFeedbackNegative)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.bottom, AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.leftBackground.ignoresSafeArea())
        .environment(\.font, .dmSans(.body))
        .tracking(BudgetTypography.appTracking)
        .confirmationDialog("Start over with a fresh plan?",
                            isPresented: $isConfirmingReset,
                            titleVisibility: .visible) {
            Button("Erase and start over", role: .destructive, action: reset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your income, expenses, savings, and spending history will be removed from this device.")
        }
    }
}

#Preview {
    StoreRecoveryView(
        error: NSError(domain: "SwiftData", code: 134110,
                       userInfo: [NSLocalizedDescriptionKey: "The model configuration used to open the store is incompatible with the one used to create the store."]),
        retry: {},
        reset: {}
    )
}
