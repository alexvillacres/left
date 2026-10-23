import SwiftUI

/// Plan detail rows follow Activity’s row rhythm and grow with larger text.
struct PlanDetailRow<Trailing: View>: View {
    @Environment(\.displayScale) private var displayScale
    let title: String
    var titleDetail: String?
    var subtitle: String?
    var accessory: ListRowAccessory = .none
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            AdaptiveValuePair {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.dmSansRowTitle())
                        .foregroundStyle(Color.leftTextPrimary)
                    if let titleDetail {
                        Text(titleDetail)
                            .font(.dmSansSupporting())
                            .foregroundStyle(Color.leftTextSecondary)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.dmSansSupporting())
                            .foregroundStyle(Color.leftTextSecondary)
                    }
                }
            } value: {
                trailing()
            }
            if accessory == .chevron {
                ListRowAccessoryImage()
                    .frame(width: 8)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if accessory == .chevron {
                Color.leftDivider.opacity(0.5).frame(height: 1 / displayScale)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct PlanDetailAmount: View {
    let amount: Decimal

    init(_ amount: Decimal) { self.amount = amount }

    var body: some View {
        MoneyText(amount: amount, showsCents: false)
            .font(.dmSans(.body, weight: .medium))
            .foregroundStyle(Color.leftTextPrimary)
            .contentTransition(.numericText())
    }
}

struct PlanDetailAddButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.dmSans(.body, weight: .medium))
            }
            .foregroundStyle(Color.leftTextPrimary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.leftNeutralFill, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.vertical, AppSpacing.sm)
    }
}
