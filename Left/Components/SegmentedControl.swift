import SwiftUI

struct SegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option

                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(.dmSans(.subheadline, weight: .medium))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.leftBackground)
                            .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                    }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .frame(minHeight: 36)
        .background(Color(uiColor: .secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
        }
    }
}
