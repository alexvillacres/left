import UIKit

@MainActor
enum HapticFeedback {
#if !targetEnvironment(simulator)
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
#endif

    static func prepareLight() {
#if !targetEnvironment(simulator)
        lightGenerator.prepare()
#endif
    }

    static func lightImpact() {
#if !targetEnvironment(simulator)
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
#endif
    }
}
