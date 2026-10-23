import SwiftUI

/// A content-sized headline group with consistent spacing below navigation.
struct ScreenHeadlineSlot<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xl)
    }
}
