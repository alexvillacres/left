import SwiftUI

/// One logged spending entry, shared by Today and Activity. The icon carries
/// the category, so every row stays on one line; a catch-up shows its range
/// beside the title.
struct TransactionRow: View {
    let transaction: Transaction
    @ScaledMetric(relativeTo: .body) private var iconSlot: CGFloat = 28

    var body: some View {
        ListRow(title: title, titleDetail: catchUpRange) {
            CategoryIcon(category: transaction.category, isCatchUp: transaction.isCatchUp)
                .font(.dmSans(.body))
                .foregroundStyle(.primary)
                .frame(width: iconSlot)
        } trailing: {
            RowAmount(spending: transaction.amount)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var title: String { transaction.displayTitle }

    private var catchUpRange: String? {
        guard transaction.isCatchUp,
              let start = transaction.catchUpStartDate,
              let end = transaction.catchUpEndDate else { return nil }
        let startText = start.formatted(.dateTime.month(.abbreviated).day())
        let endText = end.formatted(.dateTime.month(.abbreviated).day())
        return startText == endText ? startText : "\(startText)–\(endText)"
    }

    // The icon is hidden from VoiceOver, so a noted entry still names its
    // category aloud.
    private var accessibilityLabel: String {
        let detail: String?
        if let catchUpRange {
            detail = catchUpRange
        } else if title != transaction.category.label {
            detail = transaction.category.label
        } else {
            detail = nil
        }
        return [title, detail, transaction.amount.formatted(.currency(code: "USD"))]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

extension Transaction {
    /// The name a row and the undo bar show: the note, else the category.
    var displayTitle: String {
        if isCatchUp { return "Catch-up" }
        if let note, !note.isEmpty { return note }
        return category.label
    }
}
