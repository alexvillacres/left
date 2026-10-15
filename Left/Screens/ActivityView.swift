import SwiftUI
import SwiftData

struct ActivityView: View {
    @Query(sort: \MonthPlan.monthStart, order: .reverse) private var plans: [MonthPlan]
    // Owned by AppRoot so Plan stays on the same month. nil is the current month.
    @Binding var browsedMonth: Date?
    @State private var activeSpendingSheet: ActiveSpendingSheet?
    @State private var activeCatchUpSheet: ActiveCatchUpSheet?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var heroSize = 44

    private struct ActiveSpendingSheet: Identifiable {
        let id = UUID()
        let plan: MonthPlan
        var transaction: Transaction?
    }

    private struct ActiveCatchUpSheet: Identifiable {
        let id = UUID()
        let plan: MonthPlan
        let period: ClosedRange<Date>
        let transaction: Transaction
    }

    private struct SpendingDay: Identifiable {
        let date: Date
        let transactions: [Transaction]
        var id: Date { date }
        var total: Decimal { transactions.reduce(0) { $0 + $1.amount } }
    }

    private var plan: MonthPlan? {
        let target = browsedMonth ?? Calendar.current.leftMonthStart(for: .now)
        return plans.first { Calendar.current.isDate($0.monthStart, equalTo: target, toGranularity: .month) }
            ?? plans.first
    }

    var body: some View {
        NavigationStack {
            let days = plan.map(spendingDays) ?? []

            VStack(alignment: .leading, spacing: 0) {
                ScreenGroundHeader(ground: .activity) {
                    header(plan)

                    if plan != nil {
                        monthTotal(total: days.reduce(0) { $0 + $1.total })
                            .padding(.top, AppSpacing.sm)
                    }
                }

                Group {
                    if let plan {
                        if days.isEmpty {
                            Text("No spending this month")
                                .font(.dmSans(.body))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            historyList(days, plan: plan)
                        }
                    } else {
                        Text("No plan yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .screenSheet()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.leftBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $activeSpendingSheet) { sheet in
            let dates = entryDates(for: sheet.plan)
            AddSpendingView(plan: sheet.plan,
                            date: dates.upperBound,
                            transaction: sheet.transaction,
                            dateRange: dates)
        }
        .fullScreenCover(item: $activeCatchUpSheet) { sheet in
            CatchUpView(plan: sheet.plan,
                        period: sheet.period,
                        transaction: sheet.transaction)
        }
    }

    // The month names what the total and the list below are describing.
    @ViewBuilder
    private func header(_ plan: MonthPlan?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let plan {
                PeriodRow {
                    PeriodPill(
                        label: plan.monthStart.formatted(.dateTime.month(.wide).year()),
                        isEnabled: plans.count > 1,
                        accessibilityLabel: "Month, \(plan.monthStart.formatted(.dateTime.month(.wide).year()))",
                        accessibilityHint: "Choose another month"
                    ) {
                        ForEach(plans) { candidate in
                            Button {
                                select(candidate)
                            } label: {
                                if candidate.monthStart == plan.monthStart {
                                    Label(candidate.monthStart.formatted(.dateTime.month(.wide).year()),
                                          systemImage: "checkmark")
                                } else {
                                    Text(candidate.monthStart, format: .dateTime.month(.wide).year())
                                }
                            }
                        }
                    }
                } trailing: {
                    PeriodStepper(previousLabel: "Previous month",
                                  nextLabel: "Next month",
                                  canGoPrevious: month(atOffset: -1) != nil,
                                  canGoNext: month(atOffset: 1) != nil,
                                  onPrevious: { shiftMonth(-1) },
                                  onNext: { shiftMonth(1) })
                }
            }
        }
    }

    private func monthTotal(total: Decimal) -> some View {
        HeroMoneyText(amount: total, size: heroSize, suffix: "spent")
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: total)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }

    // Day headers are ordinary rows rather than section headers, so the
    // system adds no header padding or tint of its own.
    private func historyList(_ days: [SpendingDay], plan: MonthPlan) -> some View {
        List {
            ForEach(days) { day in
                ListSectionHeader(title: dayTitle(day.date),
                                  value: day.total.formatted(.currency(code: "USD")),
                                  titleWeight: .medium)
                    .padding(.top, day.id == days.first?.id ? 0 : AppSpacing.md)
                    .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())), total \(day.total.formatted(.currency(code: "USD")))")
                    .historyListRow()

                ForEach(day.transactions) { transaction in
                    Button {
                        edit(transaction, in: plan)
                    } label: {
                        TransactionRow(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit spending")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(transaction)
                            HapticFeedback.lightImpact()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(Color.leftDestructiveFill)
                    }
                    .historyListRow()
                }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.top, AppSpacing.lg, for: .scrollContent)
        .scrollContentBackground(.hidden)
    }

    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func edit(_ transaction: Transaction, in plan: MonthPlan) {
        if transaction.isCatchUp,
           let start = transaction.catchUpStartDate,
           let end = transaction.catchUpEndDate {
            activeCatchUpSheet = ActiveCatchUpSheet(plan: plan,
                                                     period: start...end,
                                                     transaction: transaction)
        } else {
            activeSpendingSheet = ActiveSpendingSheet(plan: plan, transaction: transaction)
        }
    }

    private func spendingDays(in plan: MonthPlan) -> [SpendingDay] {
        let calendar = Calendar.current
        let transactions = plan.transactions
            .filter { calendar.isDate($0.date, equalTo: plan.monthStart, toGranularity: .month) }
            .sorted { $0.date > $1.date }
        return Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
            .map { SpendingDay(date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func shiftMonth(_ delta: Int) {
        guard let target = month(atOffset: delta) else { return }
        select(target)
    }

    private func select(_ target: MonthPlan) {
        guard target.monthStart != plan?.monthStart else { return }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
            browsedMonth = Calendar.current.isDate(target.monthStart, equalTo: .now, toGranularity: .month)
                ? nil : target.monthStart
        }
        HapticFeedback.lightImpact()
    }

    private func month(atOffset delta: Int) -> MonthPlan? {
        guard let plan,
              let index = plans.firstIndex(where: { $0.persistentModelID == plan.persistentModelID }) else {
            return nil
        }
        let targetIndex = index - delta
        guard plans.indices.contains(targetIndex) else { return nil }
        return plans[targetIndex]
    }

    private func entryDates(for plan: MonthPlan) -> ClosedRange<Date> {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: plan.monthStart)!
        let lastDate = min(Date.now, nextMonth.addingTimeInterval(-1))
        return plan.monthStart...max(plan.monthStart, lastDate)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: MonthPlan.self, IncomeSource.self, SavingsGoal.self, FixedExpense.self, Transaction.self,
        configurations: config
    )
    let cal = Calendar.current
    let start = cal.startOfDay(for: cal.date(from: cal.dateComponents([.year, .month], from: .now))!)
    let plan = MonthPlan(monthStart: start, monthlyIncome: 6200, savingsGoal: 0)
    container.mainContext.insert(plan)
    plan.incomeSources.append(IncomeSource(name: "Salary", amount: 6200, cadence: .fixed, affirmedAt: .now))
    plan.savingsGoals.append(SavingsGoal(name: "Roth IRA", amount: 500))
    plan.savingsGoals.append(SavingsGoal(name: "Emergency fund", amount: 0, percent: 10))
    plan.fixedExpenses.append(FixedExpense(name: "Rent", amount: 1800))
    plan.transactions.append(Transaction(amount: 14.50, category: .food, note: "Lunch"))
    plan.transactions.append(Transaction(amount: 62, date: cal.date(byAdding: .day, value: 2, to: start)!, category: .shopping))
    plan.transactions.append(Transaction(amount: 41, date: cal.date(byAdding: .day, value: 3, to: start)!, category: .bar))
    return ActivityView(browsedMonth: .constant(nil))
        .modelContainer(container)
}

private extension View {
    func historyListRow() -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.xl, bottom: 0, trailing: AppSpacing.xl))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.leftBackground)
    }
}
