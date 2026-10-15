import SwiftUI

// Shared chrome for Today, Activity, Plan, and Settings. The point is
// continuity: every screen opens with a title row and, where the screen shows
// a period, a period row — same gutter, same row height, same type. Switching
// tabs then moves the content inside the frame instead of rebuilding the frame.
//
// The two rows are separate views rather than one fixed stack because the
// screens order them differently: Today puts its balance between the title and
// the period (the pill labels the day's spending list below it), while Activity
// and Plan pair title and period together above their totals.
enum ScreenHeaderMetrics {
    static let rowHeight: CGFloat = 44
    // Every icon in the header is one size, so icons sit on the same optical
    // line as the text beside them instead of each control setting its own.
    static let iconSize: CGFloat = 16
    // Steppers are narrower than a full target but keep the 44-point height.
    static let stepperWidth: CGFloat = 36
    // The pill's chevron is set with the label rather than as a control of its
    // own, so it takes a type-ornament size instead of the 16-point icon size.
    static let menuChevronSize: CGFloat = 10
    static let titleSize: CGFloat = 20
    static let periodSize: CGFloat = 16
}

// MARK: - Ground

/// The light color a main tab opens on (DECISIONS 030). It keeps its light
/// value in dark mode, so everything drawn on it uses fixed ground ink.
struct ScreenGround {
    let fill: Color
    let controlFill: Color
    let secondaryInk: Color

    static let today = ScreenGround(fill: .leftGroundToday,
                                    controlFill: .leftGroundTodayFill,
                                    secondaryInk: .leftGroundTodayTextSecondary)
    static let activity = ScreenGround(fill: .leftGroundActivity,
                                       controlFill: .leftGroundActivityFill,
                                       secondaryInk: .leftGroundActivityTextSecondary)
    static let plan = ScreenGround(fill: .leftGroundPlan,
                                   controlFill: .leftGroundPlanFill,
                                   secondaryInk: .leftGroundPlanTextSecondary)
    static let income = ScreenGround(fill: .leftGroundIncome,
                                     controlFill: .leftGroundIncomeFill,
                                     secondaryInk: .leftGroundIncomeTextSecondary)
    static let expenses = ScreenGround(fill: .leftGroundExpenses,
                                       controlFill: .leftGroundExpensesFill,
                                       secondaryInk: .leftGroundExpensesTextSecondary)
    static let savings = ScreenGround(fill: .leftGroundSavings,
                                      controlFill: .leftGroundSavingsFill,
                                      secondaryInk: .leftGroundSavingsTextSecondary)
}

enum ScreenGroundMetrics {
    static let cornerRadius: CGFloat = 16
    static let sheetCornerRadius: CGFloat = 34
    // How far the content sheet rises over the bottom of the ground.
    static let sheetOverlap: CGFloat = 24
}

/// The period row and headline number, set on the tab's ground. `.primary`
/// and `.secondary` resolve to the ground's fixed ink in both appearances.
/// Anything on the ground that uses an appearance-dependent color, such as a
/// state color, must also be resolved with `.environment(\.colorScheme, .light)`;
/// menus are left alone so they still follow the system.
struct ScreenGroundHeader<Content: View>: View {
    let ground: ScreenGround
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.lg + ScreenGroundMetrics.sheetOverlap)
        .foregroundStyle(Color.leftGroundTextPrimary, ground.secondaryInk, ground.secondaryInk)
        .environment(\.periodPillFill, ground.controlFill)
        .background(
            RoundedRectangle(cornerRadius: ScreenGroundMetrics.cornerRadius, style: .continuous)
                .fill(ground.fill)
        )
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
    }
}

extension View {
    /// The rounded sheet that rises over a ground header and holds the
    /// screen's content. Today uses a soft shadow; other screens retain
    /// their hairline edge.
    func screenSheet(showsOutline: Bool = true) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: ScreenGroundMetrics.sheetCornerRadius,
                                           topTrailingRadius: ScreenGroundMetrics.sheetCornerRadius,
                                           style: .continuous)
        return self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipShape(shape)
            .background(
                shape.fill(Color.leftBackground)
                    .shadow(color: .black.opacity(showsOutline ? 0 : 0.08),
                            radius: 8, x: 0, y: -2)
            )
            .overlay {
                if showsOutline {
                    shape.strokeBorder(Color.leftTabBarBorder, lineWidth: 1)
                }
            }
            .padding(.top, -ScreenGroundMetrics.sheetOverlap)
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

/// The capsule that names the current period and opens the list of the others.
struct PeriodPill<Menu: View>: View {
    let label: String
    var isEnabled = true
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
                    .font(.dmSans(.callout, weight: .medium))
                    .tracking(BudgetTypography.tracking(for: ScreenHeaderMetrics.periodSize))
                    .monospacedDigit()

                Image(systemName: "chevron.down")
                    .font(.system(size: ScreenHeaderMetrics.menuChevronSize, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 7)
            .background(Capsule().fill(fill))
            .contentShape(Capsule())
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
