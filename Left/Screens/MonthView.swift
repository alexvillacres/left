import SwiftUI
import SwiftData
import UIKit

struct MonthView: View {
    @Query(sort: \MonthPlan.monthStart, order: .reverse) private var plans: [MonthPlan]
    @State private var selectedDay: DaySelection?
    @State private var selectedMonthStart: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var heroSize = 42

    private var plan: MonthPlan? {
        let target = selectedMonthStart ?? Calendar.current.leftMonthStart(for: .now)
        return plans.first { Calendar.current.isDate($0.monthStart, equalTo: target, toGranularity: .month) }
            ?? plans.first
    }

    private struct DaySelection: Identifiable {
        let day: Int
        var id: Int { day }
    }

    private enum CalendarGridItem: Identifiable {
        case blank(Int)
        case day(Int)

        var id: String {
            switch self {
            case .blank(let index): "blank-\(index)"
            case .day(let day): "day-\(day)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let plan {
                    ScrollView {
                        VStack(spacing: AppSpacing.xl) {
                            monthTitle(plan)
                            header(plan)
                            grid(plan)
                        }
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.top, AppSpacing.sm)
                    }
                    .contentMargins(.horizontal, 0, for: .scrollContent)
                    .contentShape(Rectangle())
                    .simultaneousGesture(monthSwipeGesture)
                    .background(Color(uiColor: .systemBackground).ignoresSafeArea())
                } else {
                    Text("No plan yet")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(item: $selectedDay) { selection in
            if let plan {
                DayTransactionsSheet(plan: plan, day: selection.day)
            }
        }
    }

    // MARK: - Header

    private func monthTitle(_ plan: MonthPlan) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.xs) {
            Text(plan.monthStart.formatted(.dateTime.month(.wide).year()))
                .font(.dmSans(size: heroSize, weight: .semibold, relativeTo: .largeTitle))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: AppSpacing.sm)

            monthNavigationButton(systemName: "chevron.left", delta: -1, label: "Previous month")
            monthNavigationButton(systemName: "chevron.right", delta: 1, label: "Next month")
        }
        .padding(.top, AppSpacing.xxl)
    }

    private func header(_ plan: MonthPlan) -> some View {
        let isCurrentMonth = Calendar.current.isDate(plan.monthStart, equalTo: .now, toGranularity: .month)
        let evaluationDate = isCurrentMonth ? Date.now : endOfMonth(for: plan)
        let savings = plan.projectedSavings(on: evaluationDate)

        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                MoneyText(amount: plan.spent(asOf: evaluationDate))
                    .font(.dmSans(.title2, weight: .semibold))
                Text("of \(plan.monthlySpendable.formatted(.currency(code: "USD"))) spent")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text(isCurrentMonth
                 ? "On pace to save \(savings.formatted(.currency(code: "USD")))"
                 : "Saved \(savings.formatted(.currency(code: "USD")))")
                .font(.dmSans(.subheadline))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height),
                  abs(value.translation.width) > 50 else { return }
            shiftMonth(value.translation.width > 0 ? -1 : 1)
        }
    }

    private func monthNavigationButton(systemName: String, delta: Int, label: String) -> some View {
        Button {
            shiftMonth(delta)
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

    private func shiftMonth(_ delta: Int) {
        guard let target = month(atOffset: delta) else { return }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
            let currentMonthStart = Calendar.current.leftMonthStart(for: .now)
            selectedMonthStart = Calendar.current.isDate(target.monthStart,
                                                         equalTo: currentMonthStart,
                                                         toGranularity: .month)
                ? nil
                : target.monthStart
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

    private func endOfMonth(for plan: MonthPlan) -> Date {
        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: plan.monthStart)!
        return nextMonth.addingTimeInterval(-1)
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
        let gridItems = (0..<leadingBlanks).map(CalendarGridItem.blank)
            + (1...days).map(CalendarGridItem.day)

        return VStack(spacing: AppSpacing.md) {
            HStack {
                ForEach(Array(orderedWeekdaySymbols(cal).enumerated()), id: \.offset) { weekday in
                    Text(weekday.element)
                        .font(.dmSans(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(gridItems) { item in
                    switch item {
                    case .blank:
                        Color.clear.frame(minHeight: 44)
                    case .day(let day):
                        dayCell(day: day,
                                spent: spent[day] ?? 0,
                                dailyRate: plan.dailyRate,
                                isFuture: day > today)
                    }
                }
            }
        }
    }

    private func dayCell(day: Int, spent: Decimal, dailyRate: Decimal, isFuture: Bool) -> some View {
        Button {
            selectedDay = DaySelection(day: day)
        } label: {
            Text("\(day)")
                .font(.dmSans(.subheadline, weight: .medium))
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
        .accessibilityLabel(isFuture
            ? "Day \(day)"
            : "Day \(day), spent \(spent.formatted(.currency(code: "USD")))")
    }

    private func tint(spent: Decimal, dailyRate: Decimal, isFuture: Bool) -> Color {
        if isFuture { return .clear }
        if spent < dailyRate { return .leftPositive.opacity(0.16) }
        if spent <= dailyRate * Decimal(1.1) { return .leftWarning.opacity(0.18) }
        return .leftNegative.opacity(0.16)
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

    @Environment(\.modelContext) private var modelContext
    @State private var activeSpendingSheet: ActiveSpendingSheet?

    private struct ActiveSpendingSheet: Identifiable {
        let id = UUID()
        var transaction: Transaction?
    }

    private var date: Date {
        Calendar.current.date(byAdding: .day, value: day - 1, to: plan.monthStart)!
    }

    private var transactionDate: Date {
        let calendar = Calendar.current
        let currentTime = calendar.dateComponents([.hour, .minute, .second], from: .now)
        return calendar.date(bySettingHour: currentTime.hour ?? 0,
                             minute: currentTime.minute ?? 0,
                             second: currentTime.second ?? 0,
                             of: date) ?? date
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
                        Button {
                            activeSpendingSheet = ActiveSpendingSheet(transaction: tx)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: tx.category.symbol)
                                    .font(.dmSans(.body))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)
                                if let note = tx.note, !note.isEmpty {
                                    Text(note)
                                        .font(.dmSans(.body, weight: .medium))
                                        .lineLimit(2)
                                } else {
                                    Text(tx.category.label)
                                        .font(.dmSans(.body, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                MoneyText(amount: tx.amount)
                                    .layoutPriority(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.xl)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .alignmentGuide(.listRowSeparatorLeading) { _ in
                            0
                        }
                        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                            dimensions.width
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(tx)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .toolbar {
                if #available(iOS 26.0, *) {
                    addSpendingToolbarItem
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    addSpendingToolbarItem
                }
            }
        }
        .presentationDetents([.medium, .large])
        .fullScreenCover(item: $activeSpendingSheet) { sheet in
            AddSpendingView(plan: plan, date: transactionDate, transaction: sheet.transaction)
        }
    }

    private var addSpendingToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                activeSpendingSheet = ActiveSpendingSheet()
            } label: {
                Image(systemName: "plus")
                    .font(.dmSans(.subheadline, weight: .medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .accessibilityLabel("Add spending for \(date.formatted(.dateTime.month(.wide).day()))")
        }
    }

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        HapticFeedback.lightImpact()
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
    return MonthView()
        .modelContainer(container)
}
