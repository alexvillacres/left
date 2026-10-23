import SwiftUI

/// Template assets inherit the surrounding tint in both appearances.
struct AppIcon: View {
    let asset: String
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 24

    init(asset: String, size: CGFloat) {
        self.asset = asset
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Image(asset)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct CategoryIcon: View {
    let category: Category
    var isCatchUp = false
    var size: CGFloat = 22

    var body: some View {
        if isCatchUp {
            Image(systemName: "arrow.uturn.backward")
        } else if let asset {
            AppIcon(asset: asset, size: size)
        } else {
            Image(systemName: category.symbol)
        }
    }

    private var asset: String? {
        switch category {
        case .food: "IconDining"
        case .grocery: "IconGrocery"
        case .bar: "IconBar"
        case .transit: "IconTransit"
        case .shopping: "IconShopping"
        case .coffee: "IconCoffee"
        case .household: "IconHousehold"
        case .fun, .other: nil
        }
    }
}
