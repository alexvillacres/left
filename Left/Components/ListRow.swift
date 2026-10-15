import SwiftUI

// MARK: - Row

/// What sits at the trailing edge of a row, after its value.
enum ListRowAccessory {
    case none
    /// Opens something inside the app.
    case chevron
    /// Leaves the app.
    case external
}

/// The one list row layout: optional leading mark, a title with an optional
/// muted detail beside it, an optional subtitle, a trailing value, and an
/// accessory. Type, spacing, and height are fixed so rows match across
/// screens; callers own the tap action and VoiceOver wording.
struct ListRow<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    var titleDetail: String?
    var subtitle: String?
    var accessory: ListRowAccessory
    let leading: Leading
    let trailing: Trailing

    init(
        title: String,
        titleDetail: String? = nil,
        subtitle: String? = nil,
        accessory: ListRowAccessory = .none,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.titleDetail = titleDetail
        self.subtitle = subtitle
        self.accessory = accessory
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            leading

            valueLayout {
                VStack(alignment: .leading, spacing: 2) {
                    if let titleDetail {
                        // The detail drops beneath the title rather than
                        // squeezing it when large text can't share a line.
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                                titleText.fixedSize()
                                detailText(titleDetail)
                                    .lineLimit(1)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                titleText
                                detailText(titleDetail)
                                    .lineLimit(2)
                            }
                        }
                    } else {
                        titleText
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.dmSans(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: AppSpacing.sm)
                }

                trailing
                    .layoutPriority(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            accessoryView
        }
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var valueLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
            : AnyLayout(HStackLayout(spacing: AppSpacing.md))
    }

    private var titleText: some View {
        Text(title)
            .font(.dmSans(.body, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
    }

    private func detailText(_ detail: String) -> some View {
        Text(detail)
            .font(.dmSans(.subheadline))
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .chevron:
            ListRowAccessoryImage(systemName: "chevron.right")
        case .external:
            ListRowAccessoryImage(systemName: "arrow.up.right")
        }
    }
}

extension ListRow where Leading == EmptyView {
    init(
        title: String,
        titleDetail: String? = nil,
        subtitle: String? = nil,
        accessory: ListRowAccessory = .none,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(title: title, titleDetail: titleDetail, subtitle: subtitle,
                  accessory: accessory, leading: { EmptyView() }, trailing: trailing)
    }
}

extension ListRow where Leading == EmptyView, Trailing == EmptyView {
    init(
        title: String,
        titleDetail: String? = nil,
        subtitle: String? = nil,
        accessory: ListRowAccessory = .none
    ) {
        self.init(title: title, titleDetail: titleDetail, subtitle: subtitle,
                  accessory: accessory, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

/// The accessory glyph, also used hidden to hold the lane in section headers.
struct ListRowAccessoryImage: View {
    var systemName = "chevron.right"

    var body: some View {
        Image(systemName: systemName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(uiColor: .tertiaryLabel))
            .accessibilityHidden(true)
    }
}

// MARK: - Amount

/// A row's trailing amount. Plan amounts are whole dollars in semibold;
/// spending keeps its cents in medium.
struct RowAmount: View {
    private let text: String
    private let weight: Font.Weight

    /// A plan amount, in whole dollars.
    init(_ amount: Decimal) {
        text = amount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        weight = .semibold
    }

    /// A logged spending amount, with cents.
    init(spending amount: Decimal) {
        text = amount.formatted(.currency(code: "USD"))
        weight = .medium
    }

    /// An already formatted plan value, such as a signed total or a dash.
    init(text: String) {
        self.text = text
        weight = .semibold
    }

    var body: some View {
        Text(text)
            .font(.dmSans(.body, weight: weight))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

// MARK: - Section header

/// Names a group of rows, with an optional total in the amount lane and a
/// rule beneath. Stacks the total under the title when text is too large to
/// share a line.
struct ListSectionHeader: View {
    let title: String
    var value: String?
    var titleWeight: Font.Weight = .semibold
    /// Holds the accessory lane so the value lines up with row amounts.
    var reservesAccessory = false

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                    titleText
                    Spacer(minLength: AppSpacing.sm)
                    valueText
                    if reservesAccessory, value != nil {
                        ListRowAccessoryImage().hidden()
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    titleText
                    valueText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(.secondary)

            Rectangle()
                .fill(Color.leftDivider)
                .frame(height: 1)
        }
        .padding(.top, AppSpacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, value].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isHeader)
    }

    private var titleText: some View {
        Text(title)
            .font(.dmSans(.subheadline, weight: titleWeight))
    }

    @ViewBuilder
    private var valueText: some View {
        if let value {
            Text(value)
                .font(.dmSans(.subheadline, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Add and remove

/// The row that adds another item to a list.
struct ListAddRow: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.dmSans(.body, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Removes the row it trails. Sits beside a row rather than inside it so the
/// row itself can stay a separate tap target.
struct ListRowRemoveButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
