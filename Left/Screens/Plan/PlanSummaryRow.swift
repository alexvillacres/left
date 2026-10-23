import SwiftUI

/// A flat category row in the monthly plan; PlanView owns navigation.
struct PlanSummaryRow: View {
    let title: String
    let subtitle: String
    let amount: Decimal
    let icon: String
    var isPending = false
    let monthName: String
    @ScaledMetric(relativeTo: .body) private var iconWellSize: CGFloat = 46

    private var formattedAmount: String {
        isPending ? "—" : amount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            AppIcon(asset: icon, size: 28)
                .foregroundStyle(Color.leftIconSecondary)
                .frame(width: iconWellSize, height: iconWellSize)
                .background(Circle().fill(Color.leftIconWell))
                .overlay(Circle().strokeBorder(Color.leftBorder, lineWidth: 1))

            AdaptiveValuePair {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.dmSansRowTitle())
                        .tracking(-0.48)
                        .foregroundStyle(Color.leftTextPrimary)
                    Text(subtitle)
                        .font(.dmSans(size: 13, relativeTo: .subheadline))
                        .tracking(-0.39)
                        .foregroundStyle(Color.leftTextSecondary)
                }
            } value: {
                Text(formattedAmount)
                    .font(.dmSans(.body))
                    .tracking(-0.51)
                    .foregroundStyle(Color.leftTextPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ListRowAccessoryImage()
                .frame(width: 8)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Color.leftDividerSubtle.frame(height: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle), \(isPending ? "Amount needed" : formattedAmount)")
        .accessibilityHint("Opens \(monthName) \(title.lowercased())")
    }
}
