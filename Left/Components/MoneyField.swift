import SwiftUI

// The edit-side counterpart to MoneyText. One implementation for every place
// you type a number into a plan.
//
// Deliberately the *system* decimal pad, not NumpadView. The split across this
// app: NumpadView is for logging an expense — the thing you do five times a day,
// where cents-first entry and thumb-reachable keys buy real speed. This is for
// values you set a few times a year inside a scrolling form, where selection,
// paste and free dismissal matter more. Cents-first entry belongs to NumpadView
// and nowhere else; here `650` means 650.
struct MoneyField: View {
    enum Unit {
        case currency
        case percent
    }

    // How loud the field is. `prominent` is the card-backed hero field used in
    // onboarding and the income sheet; `inline` sits in a plan section;
    // `compact` is the secondary field tucked under an expense row.
    enum Prominence {
        case compact
        case inline
        case prominent
    }

    @Binding var value: Decimal
    var unit: Unit = .currency
    var prominence: Prominence = .inline
    var alignment: TextAlignment? = nil
    var accessibilityLabel: String
    var focus: FocusState<Bool>.Binding? = nil

    var body: some View {
        container {
            HStack(alignment: prominence == .compact ? .firstTextBaseline : symbolAlignment,
                   spacing: symbolSpacing) {
                if unit == .currency {
                    symbol("$")
                }

                field

                if unit == .percent {
                    symbol("%")
                }
            }
        }
    }

    // MARK: - Pieces

    private var field: some View {
        let base = TextField("0", value: $value, format: Decimal.FormatStyle())
            .font(fieldFont)
            .foregroundStyle(prominence == .compact ? Color.secondary : Color.primary)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(alignment ?? defaultAlignment)
            .monospacedDigit()
            .accessibilityLabel(accessibilityLabel)

        return Group {
            if let focus {
                base.focused(focus)
            } else {
                base
            }
        }
        .modifier(FieldWidth(prominence: prominence, unit: unit))
    }

    private func symbol(_ text: String) -> some View {
        Text(text)
            .font(symbolFont)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func container<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        switch prominence {
        case .compact:
            content()
        case .inline:
            content()
                .padding(.vertical, AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .prominent:
            content()
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: containerAlignment)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Style

    private var fieldFont: Font {
        switch prominence {
        case .compact:   .dmSans(.caption)
        case .inline:    .dmSans(.title3, weight: .semibold)
        case .prominent: .dmSans(size: 44, weight: .semibold, relativeTo: .largeTitle)
        }
    }

    private var symbolFont: Font {
        switch prominence {
        case .compact:   .dmSans(.caption)
        case .inline:    .dmSans(.body)
        case .prominent: .dmSans(size: 28, weight: .medium, relativeTo: .title)
        }
    }

    private var symbolAlignment: VerticalAlignment {
        prominence == .prominent ? .firstTextBaseline : .center
    }

    private var symbolSpacing: CGFloat {
        switch prominence {
        case .compact:   AppSpacing.xxs
        case .inline:    unit == .percent ? AppSpacing.xxs : AppSpacing.sm
        case .prominent: AppSpacing.xs
        }
    }

    private var defaultAlignment: TextAlignment {
        guard prominence == .prominent else { return .leading }
        return unit == .percent ? .trailing : .center
    }

    private var containerAlignment: Alignment {
        switch alignment ?? defaultAlignment {
        case .leading:  .leading
        case .trailing: .trailing
        default:        .center
        }
    }
}

// Width rules live in a modifier so the `if let focus` branches above stay one
// expression rather than two divergent chains.
private struct FieldWidth: ViewModifier {
    let prominence: MoneyField.Prominence
    let unit: MoneyField.Unit

    func body(content: Content) -> some View {
        switch (prominence, unit) {
        case (.compact, _):
            content.frame(width: 72)
        case (.inline, .currency):
            content.frame(maxWidth: 180)
        case (.inline, .percent):
            content.fixedSize()
        case (.prominent, .currency):
            content.frame(minWidth: 100, maxWidth: 220)
        case (.prominent, .percent):
            content.frame(minWidth: 80, maxWidth: 140)
        }
    }
}
