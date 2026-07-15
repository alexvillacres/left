import SwiftUI
import SwiftData
import UIKit

struct TodayView: View {
    @Query(sort: \MonthPlan.monthStart, order: .reverse) private var plans: [MonthPlan]
    @State private var activeExpenseSheet: ActiveExpenseSheet?
    @State private var pastDate: Date? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric private var heroSize = 56

    private struct ActiveExpenseSheet: Identifiable {
        let id = UUID()
        var transaction: Transaction?
    }

    private var plan: MonthPlan? {
        let currentMonthStart = Calendar.current.leftMonthStart(for: .now)
        return plans.first {
            Calendar.current.isDate($0.monthStart, equalTo: currentMonthStart, toGranularity: .month)
        }
    }

    private var displayedDate: Date { pastDate ?? .now }
    private var isToday: Bool { pastDate == nil }

    private var balanceDate: Date {
        guard let pastDate else { return .now }
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: pastDate)!
        return startOfNextDay.addingTimeInterval(-1)
    }

    private var transactionDate: Date {
        guard let pastDate else { return .now }
        let calendar = Calendar.current
        let currentTime = calendar.dateComponents([.hour, .minute, .second], from: .now)
        return calendar.date(bySettingHour: currentTime.hour ?? 0,
                             minute: currentTime.minute ?? 0,
                             second: currentTime.second ?? 0,
                             of: pastDate) ?? pastDate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateHeader
                heroSection
                transactionsSection

                if let plan {
                    bottomControls(plan: plan)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(daySwipeGesture)
            .accessibilityAction(named: "Previous day") {
                shiftDay(-1)
            }
            .accessibilityAction(named: "Next day") {
                shiftDay(1)
            }
            .background(Color.budgetBackground.ignoresSafeArea())
        }
        .sheet(item: $activeExpenseSheet) { sheet in
            if let plan {
                AddExpenseSheet(plan: plan, date: transactionDate, transaction: sheet.transaction)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active,
                  let pastDate,
                  pastDate < Calendar.current.leftMonthStart(for: .now) else { return }
            self.pastDate = nil
        }
    }

    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height),
                  abs(value.translation.width) > 50 else { return }
            shiftDay(value.translation.width > 0 ? -1 : 1)
        }
    }

    // MARK: - Date

    private var dateHeader: some View {
        Button {
            withAnimation(.spring(duration: 0.4)) {
                pastDate = nil
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text(displayedDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                if !isToday {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.figtree(.caption2))
                }
            }
            .font(.figtree(.subheadline))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isToday)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.lg)
    }

    private func shiftDay(_ delta: Int) {
        guard let plan else { return }
        let calendar = Calendar.current
        let target = calendar.date(byAdding: .day,
                                   value: delta,
                                   to: calendar.startOfDay(for: displayedDate))!
        guard target >= plan.monthStart else { return }

        let todayStart = calendar.startOfDay(for: .now)
        let newPastDate: Date? = target >= todayStart ? nil : target
        if let oldDate = pastDate, let newPastDate, calendar.isDate(oldDate, inSameDayAs: newPastDate) {
            return
        }
        guard pastDate != nil || newPastDate != nil else { return }

        withAnimation(.spring(duration: 0.4)) {
            pastDate = newPastDate
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(isToday ? "Left today" : "Left that day")
                .font(.figtree(.subheadline))
                .foregroundStyle(.secondary)

            heroAmount

            if let plan {
                dailyBudgetChip(plan.dailyRate)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 222)
        .padding(.horizontal, AppSpacing.xl)
    }

    @ViewBuilder
    private var heroAmount: some View {
        if let plan {
            let remaining = plan.remainingToday(on: balanceDate)
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
        Text("\(dailyRate.formatted(.currency(code: "USD"))) \(isToday ? "budget today" : "daily budget")")
            .font(.figtree(.subheadline, weight: .medium))
            .foregroundStyle(Color.budgetInfo)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.budgetInfo.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Transactions

    private var transactionsSection: some View {
        List {
            ForEach(todayTransactions) { tx in
                Button {
                    activeExpenseSheet = ActiveExpenseSheet(transaction: tx)
                } label: {
                    transactionRow(tx)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.budgetBackground)
                .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                    dimensions[.leading]
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(tx)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.budgetBackground)
    }

    private var todayTransactions: [Transaction] {
        guard let plan else { return [] }
        return plan.transactions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: displayedDate) }
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
                    Text(tx.category.label)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            MoneyText(amount: tx.amount)
                .layoutPriority(1)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Bottom controls

    private func bottomControls(plan: MonthPlan) -> some View {
        VStack(spacing: AppSpacing.xl) {
            addButton
            progressFooter(plan: plan)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .background(Color.budgetBackground)
    }

    private func progressFooter(plan: MonthPlan) -> some View {
        let spentToday = plan.spentToday(on: displayedDate)
        let remaining = plan.remainingToday(on: balanceDate)
        let spentValue = max(0, NSDecimalNumber(decimal: spentToday).doubleValue)
        let budgetValue = max(0.01, NSDecimalNumber(decimal: plan.dailyRate).doubleValue)

        return VStack(spacing: AppSpacing.sm) {
            ProgressView(value: min(spentValue, budgetValue), total: budgetValue)
                .tint(heroColor(remaining: remaining, dailyRate: plan.dailyRate))

            HStack {
                Text(isToday ? "Today" : displayedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.figtree(.caption))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(spentToday.formatted(.currency(code: "USD"))) of \(plan.dailyRate.formatted(.currency(code: "USD")))")
                    .font(.figtree(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    // MARK: - Add button

    private var addButton: some View {
        Button {
            activeExpenseSheet = ActiveExpenseSheet()
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

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private extension MonthPlan {
    func spentToday(on date: Date = .now, calendar: Calendar = .current) -> Decimal {
        transactions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.amount }
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
