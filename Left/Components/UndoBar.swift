import SwiftUI
import SwiftData

/// A deleted spending entry, copied before deletion so Undo can put it back
/// with the same identity, date, and catch-up range.
struct DeletedSpending: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let amount: Decimal
    private let stableID: UUID
    private let date: Date
    private let category: Category
    private let note: String?
    private let isCatchUp: Bool
    private let catchUpStartDate: Date?
    private let catchUpEndDate: Date?
    private let plan: MonthPlan?

    init(_ transaction: Transaction) {
        title = transaction.displayTitle
        amount = transaction.amount
        stableID = transaction.id
        date = transaction.date
        category = transaction.category
        note = transaction.note
        isCatchUp = transaction.isCatchUp
        catchUpStartDate = transaction.catchUpStartDate
        catchUpEndDate = transaction.catchUpEndDate
        plan = transaction.plan
    }

    func restore() {
        guard let plan else { return }
        plan.transactions.append(Transaction(amount: amount,
                                             date: date,
                                             category: category,
                                             note: note,
                                             isCatchUp: isCatchUp,
                                             catchUpStartDate: catchUpStartDate,
                                             catchUpEndDate: catchUpEndDate,
                                             id: stableID))
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// Deletes a spending entry and offers Undo. AppRoot supplies the action so
/// the bar outlives the row and stays put across tab switches.
struct DeleteSpendingAction {
    var perform: (Transaction) -> Void = { $0.modelContext?.delete($0) }

    func callAsFunction(_ transaction: Transaction) {
        perform(transaction)
    }
}

private struct DeleteSpendingKey: EnvironmentKey {
    static let defaultValue = DeleteSpendingAction()
}

extension EnvironmentValues {
    var deleteSpending: DeleteSpendingAction {
        get { self[DeleteSpendingKey.self] }
        set { self[DeleteSpendingKey.self] = newValue }
    }
}

/// Confirms a deletion in ink, naming the amount that returned to the
/// balance, with a short window to put it back.
struct UndoBar: View {
    let deleted: DeletedSpending
    let onUndo: () -> Void
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 56

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Deleted \(deleted.amount.formatted(.currency(code: "USD")))")
                    .font(.dmSans(size: 16, weight: .medium, relativeTo: .callout))
                    .monospacedDigit()
                Text(deleted.title)
                    .font(.dmSans(size: 13, relativeTo: .footnote))
                    .opacity(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(action: onUndo) {
                Text("Undo")
                    .font(.dmSans(.body, weight: .semibold))
                    .padding(.horizontal, AppSpacing.md)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo delete")
        }
        .foregroundStyle(Color.leftTextOnAccent)
        .padding(.leading, AppSpacing.lg)
        .padding(.trailing, AppSpacing.xxs)
        .padding(.vertical, AppSpacing.xxs)
        .frame(minHeight: minHeight)
        .background(Color.leftAccent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}
