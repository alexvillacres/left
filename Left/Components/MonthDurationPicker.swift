import SwiftUI

struct MonthDurationPicker: View {
    @Binding var startsOn: Date?
    @Binding var endsAfter: Date?
    @Binding var isExpanded: Bool

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    private var months: [Date] {
        let current = calendar.leftMonthStart(for: .now)
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: current) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Duration")
                        .font(.dmSans(.body, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 96, alignment: .leading)

                    Text(durationLabel)
                        .foregroundStyle(Color.leftFernAction)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .font(.dmSans(.body))
                .padding(.vertical, AppSpacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.leftDurationDivider)
                    .frame(height: 0.5)
                    .padding(.horizontal, -AppSpacing.xl)
            }

            if isExpanded {
                VStack(spacing: 14) {
                    hintRow

                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(months, id: \.self) { month in
                            monthCard(month)
                        }
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var hintRow: some View {
        if let start = startsOn, let end = endsAfter {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                let count = (calendar.dateComponents([.month], from: start, to: end).month ?? 0) + 1
                Text("\(count) \(count == 1 ? "month" : "months"), ending \(monthYear(end))")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("Clear") {
                    startsOn = nil
                    endsAfter = nil
                }
                .foregroundStyle(Color.leftFernAction)
            }
            .font(.system(size: 15))
        } else if startsOn != nil {
            Text("Tap another month to set an end")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func monthCard(_ month: Date) -> some View {
        let endpoint = month == startsOn || month == endsAfter
        let inRange = startsOn.map { start in
            let beforeEnd = endsAfter.map { end in month <= end } ?? (month == start)
            return month >= start && beforeEnd
        } ?? false

        return Button {
            select(month)
        } label: {
            VStack(spacing: 1) {
                Text(month.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(endpoint ? .white : inRange ? Color.leftFernRangeText : .primary)

                Text(month.formatted(.dateTime.year()))
                    .font(.system(size: 13))
                    .foregroundStyle(endpoint ? Color.leftFernEndpointYear : inRange ? Color.leftFernRangeYear : Color.leftMonthYear)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(endpoint ? Color.leftFernEndpoint : inRange ? Color.leftFernRangeFill : Color(uiColor: .systemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(endpoint ? Color.leftFernEndpoint : inRange ? Color.leftFernRangeFill : Color.leftMonthBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(month.formatted(.dateTime.month(.wide).year()))
        .accessibilityValue(endpoint ? "Range endpoint" : inRange ? "In range" : "Not selected")
    }

    private var durationLabel: String {
        switch (startsOn, endsAfter) {
        case (nil, _):
            return "Ongoing"
        case (let start?, nil):
            return "From \(monthYear(start)) · Ongoing"
        case (let start?, let end?):
            return "\(monthYear(start)) – \(monthYear(end))"
        }
    }

    private func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year())
    }

    private func select(_ month: Date) {
        if let start = startsOn, endsAfter == nil, month >= start {
            endsAfter = month
        } else {
            startsOn = month
            endsAfter = nil
        }
    }
}
