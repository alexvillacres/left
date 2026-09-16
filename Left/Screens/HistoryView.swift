import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \MonthPlan.monthStart, order: .reverse) private var plans: [MonthPlan]
    @State private var selectedMonthStart: Date?
    @State private var activeSpendingSheet: ActiveSpendingSheet?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.setAddAction) private var setAddAction
    @Environment(\.clearAddAction) private var clearAddAction
    @ScaledMetric private var heroSize = 42

    private struct ActiveSpendingSheet: Identifiable {
        let id = UUID()
        let plan: MonthPlan
        var transaction: Transaction?
    }

    private struct SpendingDay: Identifiable {
        let date: Date
        let transactions: [Transaction]
        var id: Date { date }
        var total: Decimal { transactions.reduce(0) { $0 + $1.amount } }
    }

    private var plan: MonthPlan? {
        let target = selectedMonthStart ?? Calendar.current.leftMonthStart(for: .now)
        return plans.first { Calendar.current.isDate($0.monthStart, equalTo: target, toGranularity: .month) }
            ?? plans.first
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("History")
                    .font(.dmSans(size: heroSize, weight: .semibold, relativeTo: .largeTitle))
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.xxl)

                if let plan {
                    let days = spendingDays(in: plan)
                    monthHeader(plan, total: days.reduce(0) { $0 + $1.total })
                        .padding(.horizontal, AppSpacing.xl)

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $activeSpendingSheet) { sheet in
            let dates = entryDates(for: sheet.plan)
            AddSpendingView(plan: sheet.plan,
                            date: dates.upperBound,
                            transaction: sheet.transaction,
                            dateRange: dates)
        }
        .onAppear { updateAddAction() }
        .onChange(of: plan?.persistentModelID) { updateAddAction() }
        .onDisappear { clearAddAction("history.add-spending") }
    }

    private func monthHeader(_ plan: MonthPlan, total: Decimal) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Text(plan.monthStart, format: .dateTime.month(.wide).year())
                    .font(.dmSans(.title3, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.sm)
                monthNavigationButton(systemName: "chevron.left", delta: -1, label: "Previous month")
                monthNavigationButton(systemName: "chevron.right", delta: 1, label: "Next month")
            }
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                MoneyText(amount: total)
                    .font(.dmSans(.title2, weight: .semibold))
                Text("spent")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func historyList(_ days: [SpendingDay], plan: MonthPlan) -> some View {
        List {
            ForEach(days) { day in
                Section {
                    ForEach(day.transactions) { transaction in
                        Button {
                            activeSpendingSheet = ActiveSpendingSheet(plan: plan, transaction: transaction)
                        } label: {
                            transactionRow(transaction)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.xl,
                                                  bottom: 0, trailing: AppSpacing.xl))
                        .listRowBackground(Color(uiColor: .systemBackground))
                        .accessibilityHint("Edit spending")
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(transaction)
                                HapticFeedback.lightImpact()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            dayTitle(day.date)
                            Spacer(minLength: AppSpacing.md)
                            MoneyText(amount: day.total)
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            dayTitle(day.date)
                            MoneyText(amount: day.total)
                        }
                    }
                    .font(.dmSans(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .padding(.vertical, AppSpacing.sm)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())), total \(day.total.formatted(.currency(code: "USD")))")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func dayTitle(_ date: Date) -> Text {
        if Calendar.current.isDateInToday(date) { return Text("Today") }
        if Calendar.current.isDateInYesterday(date) { return Text("Yesterday") }
        return Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: transaction.category.symbol)
                .font(.dmSans(.body))
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.dmSans(.body, weight: .medium))
                        .lineLimit(2)
                    Text(transaction.category.label)
                        .font(.dmSans(.caption))
                        .foregroundStyle(.secondary)
                } else {
                    Text(transaction.category.label)
                        .font(.dmSans(.body, weight: .medium))
                }
            }
            Spacer(minLength: AppSpacing.sm)
            MoneyText(amount: transaction.amount)
                .layoutPriority(1)
        }
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
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

    private func monthNavigationButton(systemName: String, delta: Int, label: String) -> some View {
        Button {
            guard let target = month(atOffset: delta) else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
                selectedMonthStart = Calendar.current.isDate(target.monthStart, equalTo: .now, toGranularity: .month)
                    ? nil : target.monthStart
            }
            HapticFeedback.lightImpact()
        } label: {
            Image(systemName: systemName)
                .font(.dmSans(.subheadline, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(month(atOffset: delta) == nil)
        .accessibilityLabel(label)
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

    private func updateAddAction() {
        guard let plan, plan.monthStart <= Date.now else {
            clearAddAction("history.add-spending")
            return
        }
        setAddAction(AddAction(id: "history.add-spending", accessibilityLabel: "Add spending") {
            activeSpendingSheet = ActiveSpendingSheet(plan: plan)
        })
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
    return HistoryView()
        .modelContainer(container)
}
