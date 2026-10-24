import SwiftUI

private struct PeriodPillFillKey: EnvironmentKey {
    static let defaultValue = Color.leftNeutralFill
}

extension EnvironmentValues {
    var periodPillFill: Color {
        get { self[PeriodPillFillKey.self] }
        set { self[PeriodPillFillKey.self] = newValue }
    }
}

/// The capsule that names the current period and opens the list of the others.
struct PeriodPill<Menu: View>: View {
    let label: String
    var isEnabled = true
    var cornerRadius: CGFloat = 100
    var accessibilityLabel: String
    var accessibilityHint: String?
    @ViewBuilder var menu: Menu
    @Environment(\.periodPillFill) private var fill

    var body: some View {
        SwiftUI.Menu {
            menu
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text(label)
                .font(.dmSans(.callout, weight: .regular))
                .tracking(BudgetTypography.tracking(for: ScreenHeaderMetrics.periodSize))
                .monospacedDigit()

                AppIcon(asset: "IconChevronDown", size: 12)
                    .foregroundStyle(isEnabled ? Color.leftTextSecondary : Color.leftDisabledForeground)
            }
            .foregroundStyle(isEnabled ? Color.leftTextPrimary : Color.leftDisabledForeground)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 7)
            .frame(minHeight: 32)
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(isEnabled ? fill : Color.leftDisabledFill))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(OpaqueButtonStyle())
        // Keep the native menu label out of surrounding content animations.
        .transaction { $0.animation = nil }
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
    }
}

/// A period pill with nothing to choose from — the same capsule, no menu.
struct StaticPeriodLabel: View {
    let label: String
    @Environment(\.periodPillFill) private var fill

    var body: some View {
        Text(label)
            .font(.dmSans(.callout, weight: .medium))
            .tracking(BudgetTypography.tracking(for: ScreenHeaderMetrics.periodSize))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 7)
            .background(Capsule().fill(fill))
    }
}

