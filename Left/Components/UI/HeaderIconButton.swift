import SwiftUI

// MARK: - Icon button

/// One icon size, one touch target. Used for every control in the header.
struct HeaderIconButton: View {
    let asset: String
    let label: String
    var hint: String?
    var width: CGFloat = ScreenHeaderMetrics.rowHeight
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppIcon(asset: asset, size: ScreenHeaderMetrics.iconSize)
                .frame(width: width, height: ScreenHeaderMetrics.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.leftTextSecondary : Color.leftDisabledForeground)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }
}

