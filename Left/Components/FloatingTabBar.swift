import SwiftUI

struct AddAction: Equatable, Identifiable {
    let id: String
    let accessibilityLabel: String
    let perform: () -> Void

    static func == (lhs: AddAction, rhs: AddAction) -> Bool {
        lhs.id == rhs.id
            && lhs.accessibilityLabel == rhs.accessibilityLabel
    }
}

private struct SetAddActionKey: EnvironmentKey {
    static let defaultValue: (AddAction?) -> Void = { _ in }
}

private struct ClearAddActionKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var setAddAction: (AddAction?) -> Void {
        get { self[SetAddActionKey.self] }
        set { self[SetAddActionKey.self] = newValue }
    }

    var clearAddAction: (String) -> Void {
        get { self[ClearAddActionKey.self] }
        set { self[ClearAddActionKey.self] = newValue }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case activity
    case plan

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .activity: "clock.arrow.circlepath"
        case .plan: "slider.horizontal.3"
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

// A content-width capsule floating clear of the screen edges rather than a bar
// pinned to the bottom. Separation comes from the shadow, not from a material:
// on a white screen a translucent bar has nothing behind it to reveal and
// collapses into gray.
struct FloatingTabBar: View {
    @Binding var selection: AppTab
    let addAction: AddAction?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var activePill

    // Published so callers can reserve the matching bottom inset.
    static let height: CGFloat = 56

    private let itemWidth: CGFloat = 64
    private let itemHeight: CGFloat = 44

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            tabCapsule

            if let addAction {
                actionSlot(addAction)
            }
        }
        .frame(height: Self.height)
        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: addAction != nil)
    }

    private var tabCapsule: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(AppTab.allCases) { tab in
                item(tab)
            }
        }
        .padding(AppSpacing.xs)
        .background {
            Capsule()
                .fill(Color.leftTabBarSurface)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .overlay {
            Capsule().strokeBorder(Color.leftTabBarBorder, lineWidth: 0.5)
        }
        .frame(height: Self.height)
        .accessibilityElement(children: .contain)
    }

    private func actionSlot(_ action: AddAction) -> some View {
        ZStack {
            if reduceMotion {
                actionButton(action)
                    .id(action.id)
            } else {
                actionButton(action)
                    .id(action.id)
                    .transition(.blurReplace)
            }
        }
        .frame(width: Self.height, height: Self.height)
        .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.2), value: addAction?.id)
    }

    private func actionButton(_ action: AddAction) -> some View {
        Button(action: action.perform) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.leftAccent)
                .frame(width: Self.height, height: Self.height)
                .background {
                    Circle()
                        .fill(Color.leftTabBarSurface)
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.leftTabBarBorder, lineWidth: 0.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.accessibilityLabel)
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return Button {
            select(tab)
        } label: {
            Image(systemName: tab.systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(width: itemWidth, height: itemHeight)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.leftTabActiveFill)
                            .matchedGeometryEffect(id: "activePill", in: activePill)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func select(_ tab: AppTab) {
        guard tab != selection else { return }
        HapticFeedback.lightImpact()
        withAnimation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.2)) {
            selection = tab
        }
    }
}

#Preview {
    @Previewable @State var selection: AppTab = .today

    VStack {
        Spacer()
        FloatingTabBar(
            selection: $selection,
            addAction: AddAction(
                id: "preview.add-spending",
                accessibilityLabel: "Add spending",
                perform: {}
            )
        )
    }
    .frame(maxWidth: .infinity)
    .background(Color(uiColor: .systemBackground))
}
