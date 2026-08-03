import SwiftUI

// 3×4 keypad: 1–9, blank, 0, backspace. Cents-first entry upstream
// means no "." key is needed.
struct NumpadView: View {
    let onDigit: (Int) -> Void
    let onBackspace: () -> Void
    @ScaledMetric private var keyHeight = 56

    private let rows: [[Key]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.blank, .digit(0), .backspace],
    ]

    private enum Key: Hashable {
        case digit(Int)
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
        case .backspace:
            keyButton { onBackspace() } label: {
                Image(systemName: "delete.backward")
            }
            .accessibilityLabel("Delete")
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
