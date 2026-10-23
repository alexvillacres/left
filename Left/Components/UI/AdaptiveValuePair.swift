import SwiftUI

/// Centers a value beside its label block, placing it below the label at
/// accessibility text sizes. Callers retain their typography and semantics.
struct AdaptiveValuePair<Label: View, Value: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let label: Label
    private let value: Value

    init(@ViewBuilder label: () -> Label, @ViewBuilder value: () -> Value) {
        self.label = label()
        self.value = value()
    }

    var body: some View {
        layout {
            label
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: AppSpacing.sm)
            }
            value
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: AppSpacing.md))
    }
}
