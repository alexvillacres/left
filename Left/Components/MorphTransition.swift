import SwiftUI

// A presented screen can grow out of the control that opened it instead of
// sliding over it, so the tapped element stays the subject. The system zoom
// transition needs iOS 18; older systems keep the standard presentation.
extension View {
    @ViewBuilder
    func morphSource(id: String, in namespace: Namespace.ID,
                     cornerRadius: CGFloat, active: Bool = true) -> some View {
        if #available(iOS 18, *), active {
            // Only rounded rectangles are supported; half the side is a circle.
            matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(.rect(cornerRadius: cornerRadius))
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func morphDestination(id: String, in namespace: Namespace.ID, active: Bool = true) -> some View {
        if #available(iOS 18, *), active {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
