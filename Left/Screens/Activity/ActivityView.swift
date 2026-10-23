import SwiftUI
import SwiftData

struct ActivityView: View {
    @Query(sort: \MonthPlan.monthStart, order: .reverse) private var plans: [MonthPlan]
    // Owned by AppRoot so Plan stays on the same month. nil is the current month.
    @Binding var browsedMonth: Date?
    @State private var activeSpendingSheet: ActiveSpendingSheet?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct ActiveSpendingSheet: Identifiable {
        let id = UUID()
        let plan: MonthPlan
        var transaction: Transaction?
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
                ActivityHeader(plan: plan, plans: plans,
                               total: days.reduce(0) { $0 + $1.total },
                               canGoPrevious: month(atOffset: -1) != nil,
                               canGoNext: month(atOffset: 1) != nil,
                               onSelect: select,
                               onPrevious: { shiftMonth(-1) },
                               onNext: { shiftMonth(1) })

                Group {
                    if let plan {
                        if days.isEmpty {
                            Text("No spending this month")
                                .font(.dmSansSupporting())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ActivityHistoryList(days: days) { transaction in
                                edit(transaction, in: plan)
                            }
                        }
                    } else {
                        Text("No plan yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .screenContent()
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
    }

    private func edit(_ transaction: Transaction, in plan: MonthPlan) {
        activeSpendingSheet = ActiveSpendingSheet(plan: plan, transaction: transaction)
    }

    private func spendingDays(in plan: MonthPlan) -> [ActivitySpendingDay] {
        let calendar = Calendar.current
        let transactions = plan.transactions
            .filter { calendar.isDate($0.date, equalTo: plan.monthStart, toGranularity: .month) }
            .sorted { $0.date > $1.date }
        return Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
            .map { ActivitySpendingDay(date: $0.key, transactions: $0.value) }
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
