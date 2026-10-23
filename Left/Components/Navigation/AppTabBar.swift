import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case activity
    case plan

    var id: String { rawValue }

    var iconAsset: String {
        switch self {
        case .today: "Today"
        case .activity: "IconActivity"
        case .plan: "IconPlan"
        }
    }

    // Icon-only in the bar, so the name lives here for VoiceOver.
    var title: String {
        switch self {
        case .today: "Today"
        case .activity: "Activity"
        case .plan: "Plan"
        }
    }
}

// A full-width bar under the screen, separated from content by a 1-point divider.
// It holds navigation only: the add-spending action belongs to Today.
struct AppTabBar: View {
    @Binding var selection: AppTab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastPressHaptic: (tab: AppTab, time: Date)?

    private let itemHeight: CGFloat = 44

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                item(tab)
            }
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppSpacing.xs)
        .frame(maxWidth: .infinity)
        .background {
            Color.leftTabBarSurface
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.leftTabBarBorder)
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return Button {
            select(tab)
        } label: {
            AppIcon(asset: tab.iconAsset, size: 30)
                .foregroundStyle(isSelected ? Color.primary : Color.leftTabInactive)
                .frame(maxWidth: .infinity, minHeight: itemHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(TabPressStyle {
            guard tab != selection else { return }
            HapticFeedback.lightImpact()
            lastPressHaptic = (tab, .now)
        })
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func select(_ tab: AppTab) {
        guard tab != selection else { return }
        // Accessibility activation may skip the pressed state, so the button
        // action keeps a fallback without doubling a recent touch haptic.
        let alreadyFired = lastPressHaptic.map {
            $0.tab == tab && Date.now.timeIntervalSince($0.time) < 10
        } ?? false
        if !alreadyFired { HapticFeedback.lightImpact() }
        lastPressHaptic = nil
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.20)) {
            selection = tab
        }
    }
}

private struct TabPressStyle: ButtonStyle {
    let onPress: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { onPress() }
            }
    }
}

#Preview {
    @Previewable @State var selection: AppTab = .today

    VStack {
        Spacer()
        AppTabBar(selection: $selection)
    }
    .background(Color.leftBackground)
}
