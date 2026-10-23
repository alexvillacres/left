import SwiftUI

// MARK: - Period row

/// The period being browsed, plus its stepper. Sits at the same height as the
/// title row so the two read as one block wherever a screen stacks them.
struct PeriodRow<Label: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var label: Label
    @ViewBuilder var trailing: Trailing

    var body: some View {
        layout {
            label
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: AppSpacing.sm)
            }
            trailing
        }
        .frame(minHeight: ScreenHeaderMetrics.rowHeight)
    }
}

private extension PeriodRow {
    var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
            : AnyLayout(HStackLayout(spacing: AppSpacing.xs))
    }
}

/// A centered period picker flanked by independently accessible navigation.
struct PeriodNavigationRow<Label: View>: View {
    let stepper: PeriodStepper
    @ViewBuilder var label: Label

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            HeaderIconButton(systemImage: "chevron.left",
                             label: stepper.previousLabel,
                             isEnabled: stepper.canGoPrevious,
                             action: stepper.onPrevious)
            label
                .frame(maxWidth: .infinity)
            HeaderIconButton(systemImage: "chevron.right",
                             label: stepper.nextLabel,
                             isEnabled: stepper.canGoNext,
                             action: stepper.onNext)
        }
        .frame(minHeight: ScreenHeaderMetrics.rowHeight)
    }
}

/// Previous/next through adjacent periods.
struct PeriodStepper: View {
    var previousLabel: String
    var nextLabel: String
    var canGoPrevious: Bool
    var canGoNext: Bool
    var onPrevious: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            HeaderIconButton(systemImage: "chevron.left",
                             label: previousLabel,
                             width: ScreenHeaderMetrics.stepperWidth,
                             isEnabled: canGoPrevious,
                             action: onPrevious)

            HeaderIconButton(systemImage: "chevron.right",
                             label: nextLabel,
                             width: ScreenHeaderMetrics.stepperWidth,
                             isEnabled: canGoNext,
                             action: onNext)
        }
    }
}

/// Returns to the current period, with plain ink beside the filled date pill.
struct PeriodResetButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: ScreenHeaderMetrics.iconSize, weight: .medium))
                Text(title)
                    .font(.dmSans(.subheadline, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, AppSpacing.sm)
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Return to \(title.lowercased())")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        ScreenTitleRow(title: "Activity") {
            HeaderIconButton(systemImage: "clock.arrow.circlepath",
                             label: "Catch up spending") {}
        }

        PeriodRow {
            StaticPeriodLabel(label: "September 2026")
        } trailing: {
            PeriodStepper(previousLabel: "Previous month",
                          nextLabel: "Next month",
                          canGoPrevious: true,
                          canGoNext: false,
                          onPrevious: {},
                          onNext: {})
        }
    }
    .padding(.horizontal, AppSpacing.xl)
    .padding(.vertical, AppSpacing.sm)
    .background(Color.leftBackground)
}
