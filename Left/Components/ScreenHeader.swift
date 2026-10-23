import SwiftUI

// Shared period navigation and headline chrome for the main screens.
enum ScreenHeaderMetrics {
    static let rowHeight: CGFloat = 44
    // Every icon in the header is one size, so icons sit on the same optical
    // line as the text beside them instead of each control setting its own.
    static let iconSize: CGFloat = 16
    // Keep adjacent-period controls comfortably tappable.
    static let stepperWidth: CGFloat = 44
    // The pill's chevron is set with the label rather than as a control of its
    // own, so it takes a type-ornament size instead of the 16-point icon size.
    static let menuChevronSize: CGFloat = 10
    static let titleSize: CGFloat = 20
    static let periodSize: CGFloat = 16
}

// MARK: - Screen foundation

/// A neutral, adaptive header with one headline and optional exception content.
struct ScreenHeader<Content: View>: View {
    @Environment(\.displayScale) private var displayScale
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.xl)
        .foregroundStyle(Color.leftTextPrimary, Color.leftTextSecondary, Color.leftTextSecondary)
        .environment(\.periodPillFill, Color.leftNeutralFill)
        .background(Color.leftBackground)
        .overlay(alignment: .bottom) {
            Color.leftDivider.frame(height: 1 / displayScale)
        }
    }
}

extension View {
    /// Flat content continues on the same neutral surface below the header.
    func screenContent() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.leftBackground)
    }
}

private struct PeriodPillFillKey: EnvironmentKey {
    static let defaultValue = Color.leftNeutralFill
}

extension EnvironmentValues {
    var periodPillFill: Color {
        get { self[PeriodPillFillKey.self] }
        set { self[PeriodPillFillKey.self] = newValue }
    }
}

// MARK: - Title row

/// The screen's name, plus at most one contextual action.
struct ScreenTitleRow<Action: View>: View {
    let title: String
    @ViewBuilder var action: Action

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.dmSans(.title3, weight: .semibold))
                .tracking(BudgetTypography.tracking(for: ScreenHeaderMetrics.titleSize))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: AppSpacing.sm)

            action
        }
        .frame(minHeight: ScreenHeaderMetrics.rowHeight)
    }
}

extension ScreenTitleRow where Action == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

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

                Image(systemName: "chevron.down")
                    .font(.system(size: ScreenHeaderMetrics.menuChevronSize, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 7)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(fill))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
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

// MARK: - Icon button

/// One icon size, one touch target. Used for every control in the header.
struct HeaderIconButton: View {
    let systemImage: String
    let label: String
    var hint: String?
    var width: CGFloat = ScreenHeaderMetrics.rowHeight
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: ScreenHeaderMetrics.iconSize, weight: .medium))
                .frame(width: width, height: ScreenHeaderMetrics.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
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
