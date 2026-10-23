import SwiftUI

/// The quiet category mark shared by Today and Activity spending rows.
struct SpendingRowIcon: View {
    let category: Category
    var isCatchUp = false
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = 20

    var body: some View {
        CategoryIcon(category: category, isCatchUp: isCatchUp, size: 20)
            .font(.system(size: glyphSize))
            .foregroundStyle(Color.leftIconSecondary)
            .frame(width: diameter, height: diameter)
            .background(Color.leftIconWell, in: Circle())
            .overlay {
                Circle().strokeBorder(Color.leftBorder, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

}
