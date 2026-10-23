import SwiftUI

/// Keeps explicit disabled colors intact instead of applying system dimming.
struct OpaqueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
