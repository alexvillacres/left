import SwiftUI

struct ActivitySpendingDay: Identifiable {
    let date: Date
    let transactions: [Transaction]
    var id: Date { date }
    var total: Decimal { transactions.reduce(0) { $0 + $1.amount } }
}

/// The month’s grouped spending rows; the screen owns editing presentation.
struct ActivityHistoryList: View {
    let days: [ActivitySpendingDay]
    let onEdit: (Transaction) -> Void
    @Environment(\.deleteSpending) private var deleteSpending

    var body: some View {
        List {
            ForEach(days) { day in
                if day.id != days.first?.id {
                    Rectangle()
                        .fill(Color.leftDivider)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                        .historyListRow(horizontalInset: 0)
                }

                ListSectionHeader(title: dayTitle(day.date),
                                  value: day.total.formatted(.currency(code: "USD")),
                                  titleWeight: .medium,
                                  showsDivider: false,
                                  bottomPadding: AppSpacing.sm)
                    .padding(.top, AppSpacing.md)
                    .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())), total \(day.total.formatted(.currency(code: "USD")))")
                    .historyListRow()

                ForEach(day.transactions) { transaction in
                    Button {
                        onEdit(transaction)
                    } label: {
                        TransactionRow(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit spending")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteSpending(transaction)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(Color.leftDestructiveFill)
                    }
                    // Keep rows separate for swipe actions. Only the final row
                    // supplies the day group's bottom padding; row height and
                    // internal spacing belong to TransactionRow / ListRow.
                    .padding(.bottom, transaction.id == day.transactions.last?.id ? AppSpacing.md : 0)
                    .historyListRow()
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
    }

    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

}

private extension View {
    func historyListRow(horizontalInset: CGFloat = AppSpacing.xl) -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: horizontalInset, bottom: 0, trailing: horizontalInset))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.leftBackground)
    }
}
