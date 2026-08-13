import SwiftUI

struct PlanSheetHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(.dmSans(size: BudgetTypography.headingSize, weight: .bold, relativeTo: .title2))
                .tracking(BudgetTypography.headingTracking)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.dmSans(.subheadline))
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct PlanSheetRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.dmSans(.body, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.dmSans(.body))
        .padding(.vertical, AppSpacing.lg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.leftDurationDivider)
                .frame(height: 0.5)
                .padding(.horizontal, -AppSpacing.xl)
        }
    }
}

struct PlanSheetActions: View {
    let primaryTitle: String
    let isEnabled: Bool
    let save: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Button(action: save) {
                Text(primaryTitle)
                    .font(.dmSans(.body, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.35)

            Button("Cancel", action: cancel)
                .font(.dmSans(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
    }
}
