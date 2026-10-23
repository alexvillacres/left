import SwiftUI

// MARK: - Title row

/// The screen's name, plus at most one contextual action.
struct ScreenTitleRow<Action: View>: View {
    let title: String
    @ViewBuilder var action: Action

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.dmSans(.title3, weight: .medium))
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

