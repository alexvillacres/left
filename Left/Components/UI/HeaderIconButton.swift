import SwiftUI

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

