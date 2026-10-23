import SwiftUI

// Shared period navigation and headline chrome for the main screens.
enum ScreenHeaderMetrics {
    static let rowHeight: CGFloat = 44
    // Every icon in the header is one size, so icons sit on the same optical
    // line as the text beside them instead of each control setting its own.
    static let iconSize: CGFloat = 16
    // Keep adjacent-period controls comfortably tappable.
    static let stepperWidth: CGFloat = 44
    // The pill's chevron is set with the label rather than as a control of its
    // own, so it takes a type-ornament size instead of the 16-point icon size.
    static let menuChevronSize: CGFloat = 10
    static let titleSize: CGFloat = 20
    static let periodSize: CGFloat = 16
}

// MARK: - Screen foundation

/// A neutral, adaptive header with one headline and optional exception content.
struct ScreenHeader<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.xl)
        .foregroundStyle(Color.leftTextPrimary, Color.leftTextSecondary, Color.leftTextSecondary)
        .environment(\.periodPillFill, Color.leftNeutralFill)
        .background(Color.leftBackground)
        .overlay(alignment: .bottom) {
            Color.leftDivider.frame(height: 1)
        }
    }
}

extension View {
    /// Flat content continues on the same neutral surface below the header.
    func screenContent() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.leftBackground)
    }
}
