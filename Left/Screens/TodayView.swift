import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \MonthPlan.monthStart, order: .reverse) private var plans: [MonthPlan]
    @State private var showingAddExpense = false
    @ScaledMetric private var heroSize = 56

    private var plan: MonthPlan? {
        let currentMonthStart = Calendar.current.leftMonthStart(for: .now)
        return plans.first {
            Calendar.current.isDate($0.monthStart, equalTo: currentMonthStart, toGranularity: .month)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date
                Text(Date.now, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.figtree(.subheadline))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.lg)

                // Hero number — dominates the screen
                VStack(spacing: AppSpacing.lg) {
                    Text("Left to spend today")
                        .font(.figtree(.subheadline))
                        .foregroundStyle(.secondary)

                    heroAmount

                    if let plan {
                        dailyBudgetChip(plan.dailyRate)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Today's transactions
                VStack(spacing: 0) {
                    ForEach(todayTransactions) { tx in
                        transactionRow(tx)
                        Divider()
                            .overlay(Color.budgetDivider)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color.budgetBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let plan { footerBar(plan: plan) }
            }
            .overlay(alignment: .bottom) {
                addFAB
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.xxl + AppSpacing.xl + AppSpacing.lg) // clears footer
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            if let plan {
                AddExpenseSheet(plan: plan)
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroAmount: some View {
        if let plan {
            let remaining = plan.remainingForToday()
            HeroMoneyText(amount: remaining, size: heroSize)
                .padding(.horizontal, AppSpacing.xl)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.4), value: remaining)
        } else {
            Text("$–")
                .font(.figtree(size: heroSize, weight: .semibold, relativeTo: .largeTitle))
                .foregroundStyle(.secondary)
        }
    }

    private func heroColor(remaining: Decimal, dailyRate: Decimal) -> Color {
        if remaining > dailyRate / 4 { return .budgetPositive }
        if remaining > 0 { return .budgetWarning }
        return .budgetNegative
    }

    // MARK: - Daily budget chip

    private func dailyBudgetChip(_ dailyRate: Decimal) -> some View {
        Text("\(dailyRate.formatted(.currency(code: "USD"))) budget today")
            .font(.figtree(.subheadline, weight: .medium))
            .foregroundStyle(Color.budgetInfo)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.budgetInfo.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Transactions

    private var todayTransactions: [Transaction] {
        guard let plan else { return [] }
        return plan.transactions
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    private func transactionRow(_ tx: Transaction) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: tx.category.symbol)
                .font(.figtree(.body))
                .foregroundStyle(Color.budgetInfo)
                .frame(width: 28)
            if let note = tx.note, !note.isEmpty {
                Text(note)
                    .lineLimit(2)
            } else {
                Text(tx.category.rawValue.capitalized)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            MoneyText(amount: tx.amount)
                .layoutPriority(1)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Footer

    private func footerBar(plan: MonthPlan) -> some View {
        let spentToday = plan.spentToday()
        let remaining = plan.remainingForToday()
        let spentValue = max(0, NSDecimalNumber(decimal: spentToday).doubleValue)
        let budgetValue = max(0.01, NSDecimalNumber(decimal: plan.dailyRate).doubleValue)

        return VStack(spacing: AppSpacing.sm) {
            ProgressView(value: min(spentValue, budgetValue), total: budgetValue)
                .tint(heroColor(remaining: remaining, dailyRate: plan.dailyRate))
                .padding(.horizontal, AppSpacing.xl)

            HStack {
                Text("Today")
                    .font(.figtree(.caption))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(spentToday.formatted(.currency(code: "USD"))) of \(plan.dailyRate.formatted(.currency(code: "USD")))")
                    .font(.figtree(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, AppSpacing.xl)
        }
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .background(Color.budgetSurface)
    }

    // MARK: - FAB

    private var addFAB: some View {
        Button {
            showingAddExpense = true
        } label: {
            Text("Add Expense")
                .font(.figtree(size: 17, weight: .semibold))
                .foregroundStyle(Color.budgetPrimaryActionForeground)
                .padding(.horizontal, AppSpacing.xl)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(Color.budgetPrimaryAction)
                .clipShape(Capsule())
        }
        .accessibilityLabel("Add Expense")
    }
}

private extension MonthPlan {
    func spentToday(on date: Date = .now, calendar: Calendar = .current) -> Decimal {
        transactions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.amount }
    }

    func remainingForToday(on date: Date = .now, calendar: Calendar = .current) -> Decimal {
        dailyRate - spentToday(on: date, calendar: calendar)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: MonthPlan.self, FixedExpense.self, Transaction.self,
        configurations: config
    )
    let cal = Calendar.current
    let start = cal.startOfDay(for: cal.date(from: cal.dateComponents([.year, .month], from: .now))!)
    let plan = MonthPlan(monthStart: start, monthlyIncome: 6200, savingsGoal: 1000)
    container.mainContext.insert(plan)
    plan.fixedExpenses.append(FixedExpense(name: "Rent", amount: 1800))
    plan.transactions.append(Transaction(amount: 14.50, category: .food, note: "Lunch"))
    plan.transactions.append(Transaction(amount: 4.75, category: .coffee))
    return TodayView()
        .modelContainer(container)
}
