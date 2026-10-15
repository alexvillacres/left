import SwiftUI

// 3×4 keypad: 1–9, blank, 0, backspace. Cents-first entry upstream
// means no "." key is needed; whole-dollar entry passes `onDecimal` and the
// blank becomes one.
//
// Keys grow with Dynamic Type only through the largest standard size. Beyond
// that, accessibility sizes would push the keypad past the screen while the
// digits are already large; the amount it enters keeps scaling.
struct NumpadView: View {
    let onDigit: (Int) -> Void
    let onBackspace: () -> Void
    var onDecimal: (() -> Void)? = nil
    var body: some View {
        NumpadKeys(onDigit: onDigit, onBackspace: onBackspace, onDecimal: onDecimal)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

// Apply the size limit outside the view that owns the scaled metric, so key
// heights and labels resolve against the same capped environment.
private struct NumpadKeys: View {
    let onDigit: (Int) -> Void
    let onBackspace: () -> Void
    let onDecimal: (() -> Void)?
    @ScaledMetric private var keyHeight = 56

    private var rows: [[Key]] {
        [
            [.digit(1), .digit(2), .digit(3)],
            [.digit(4), .digit(5), .digit(6)],
            [.digit(7), .digit(8), .digit(9)],
            [onDecimal == nil ? .blank : .decimal, .digit(0), .backspace],
        ]
    }

    private enum Key: Hashable {
        case digit(Int)
        case decimal
        case blank
        case backspace
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: AppSpacing.sm) {
                    ForEach(row, id: \.self) { key in
                        keyView(key)
                    }
                }
                .frame(height: keyHeight)
            }
        }
    }

    @ViewBuilder
    private func keyView(_ key: Key) -> some View {
        switch key {
        case .digit(let n):
            keyButton { onDigit(n) } label: {
                Text("\(n)")
            }
        case .decimal:
            keyButton { onDecimal?() } label: {
                Text(Locale.current.decimalSeparator ?? ".")
            }
            .accessibilityLabel("Decimal point")
        case .backspace:
            keyButton { onBackspace() } label: {
                Image(systemName: "delete.backward")
            }
            .accessibilityLabel("Backspace")
        case .blank:
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: keyHeight)
        }
    }

    private func keyButton(action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
                .font(.dmSans(.title2, weight: .medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: keyHeight)
                .background(Color(uiColor: .secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NumpadView(onDigit: { _ in }, onBackspace: {})
        .padding(AppSpacing.lg)
}
