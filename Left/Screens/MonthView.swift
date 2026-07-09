import SwiftUI
import SwiftData

struct MonthView: View {
    @Query(sort: \MonthPlan.monthStart, order: .reverse) private var plans: [MonthPlan]
    @State private var selectedDay: DaySelection?

    private var plan: MonthPlan? {
        let currentMonthStart = Calendar.current.leftMonthStart(for: .now)
        return plans.first {
            Calendar.current.isDate($0.monthStart, equalTo: currentMonthStart, toGranularity: .month)
        }
    }

    private struct DaySelection: Identifiable {
        let day: Int
        var id: Int { day }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let plan {
                    ScrollView {
                        VStack(spacing: AppSpacing.xl) {
                            header(plan)
                            grid(plan)
                        }
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.top, AppSpacing.sm)
                    }
                    .background(Color.budgetBackground.ignoresSafeArea())
                } else {
                    Text("No plan yet")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(Date.now.formatted(.dateTime.month(.wide)))
        }
        .sheet(item: $selectedDay) { selection in
            if let plan {
                DayTransactionsSheet(plan: plan, day: selection.day)
            }
        }
    }

    // MARK: - Header

    private func header(_ plan: MonthPlan) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                MoneyText(amount: plan.spent())
                    .font(.figtree(.title2, weight: .semibold))
                Text("of \(plan.monthlySpendable.formatted(.currency(code: "USD"))) spent")
                    .font(.figtree(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text("On pace to save \(plan.projectedSavings().formatted(.currency(code: "USD")))")
                .font(.figtree(.subheadline))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Grid

    private func grid(_ plan: MonthPlan) -> some View {
        let cal = Calendar.current
        let days = plan.daysInMonth()
        let isCurrentMonth = cal.isDate(plan.monthStart, equalTo: .now, toGranularity: .month)
        let today = isCurrentMonth ? cal.component(.day, from: .now) : days
        let firstWeekday = cal.component(.weekday, from: plan.monthStart)
        let leadingBlanks = (firstWeekday - cal.firstWeekday + 7) % 7
        let spent = spentByDay(plan)
        let columns = Array(repeating: GridItem(.flexible(minimum: 36), spacing: AppSpacing.sm), count: 7)

        return VStack(spacing: AppSpacing.md) {
            HStack {
                ForEach(orderedWeekdaySymbols(cal), id: \.self) { symbol in
                    Text(symbol)
                        .font(.figtree(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(minHeight: 44)
                }
                ForEach(1...days, id: \.self) { day in
                    dayCell(day: day,
                            spent: spent[day] ?? 0,
                            dailyRate: plan.dailyRate,
                            isFuture: day > today)
                }
            }
        }
    }

    private func dayCell(day: Int, spent: Decimal, dailyRate: Decimal, isFuture: Bool) -> some View {
        Button {
            selectedDay = DaySelection(day: day)
        } label: {
            Text("\(day)")
                .font(.figtree(.subheadline, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(isFuture ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(tint(spent: spent, dailyRate: dailyRate, isFuture: isFuture))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private func tint(spent: Decimal, dailyRate: Decimal, isFuture: Bool) -> Color {
        if isFuture { return .clear }
        if spent < dailyRate { return .budgetPositiveFill }
        if spent <= dailyRate * Decimal(1.1) { return .budgetWarningFill }
        return .budgetNegativeFill
    }

    private func spentByDay(_ plan: MonthPlan) -> [Int: Decimal] {
        let cal = Calendar.current
        var totals: [Int: Decimal] = [:]
        for tx in plan.transactions {
            guard cal.isDate(tx.date, equalTo: plan.monthStart, toGranularity: .month) else { continue }
            totals[cal.component(.day, from: tx.date), default: 0] += tx.amount
        }
        return totals
    }

    private func orderedWeekdaySymbols(_ cal: Calendar) -> [String] {
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

// MARK: - Day detail

private struct DayTransactionsSheet: View {
    let plan: MonthPlan
    let day: Int

    private var date: Date {
        Calendar.current.date(byAdding: .day, value: day - 1, to: plan.monthStart)!
    }

    private var transactions: [Transaction] {
        let cal = Calendar.current
        return plan.transactions
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    Text("Nothing spent")
                        .foregroundStyle(.secondary)
                } else {
                    List(transactions) { tx in
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
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
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
    plan.transactions.append(Transaction(amount: 62, date: cal.date(byAdding: .day, value: 2, to: start)!, category: .shopping))
    plan.transactions.append(Transaction(amount: 41, date: cal.date(byAdding: .day, value: 3, to: start)!, category: .fun))
    return MonthView()
        .modelContainer(container)
}
