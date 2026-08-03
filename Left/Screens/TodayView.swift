import SwiftUI
import SwiftData
import UIKit

struct TodayView: View {
    @Query(sort: \MonthPlan.monthStart, order: .reverse) private var plans: [MonthPlan]
    @State private var activeSpendingSheet: ActiveSpendingSheet?
    @State private var pastDate: Date? = nil
    @State private var isEditingIncome = false
    @State private var recalcNote: String?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var heroSize = 42
    // Scales so the block grows with the type inside it instead of clipping.
    @ScaledMetric private var heroBlockHeight: CGFloat = 220

    private struct ActiveSpendingSheet: Identifiable {
        let id = UUID()
        var transaction: Transaction?
    }

    private var plan: MonthPlan? {
        planContaining(displayedDate)
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
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        }
        .sheet(item: $activeSpendingSheet) { sheet in
            if let plan {
                AddSpendingSheet(plan: plan, date: transactionDate, transaction: sheet.transaction)
            }
        }
        .sheet(isPresented: $isEditingIncome) {
            if let plan {
                IncomeSheet(plan: plan) { changed in
                    if changed { noteRecalculation(plan) }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            // Session-scoped: the explanation is for the jump you just watched.
            recalcNote = nil
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

    @ViewBuilder
    private var dateContext: some View {
        HStack(spacing: AppSpacing.xs) {
            if isToday {
                Text("Today")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
            } else {
                pastDateButton
            }

            Spacer()

            dayNavigationButton(systemName: "chevron.left", delta: -1, label: "Previous day")
            dayNavigationButton(systemName: "chevron.right", delta: 1, label: "Next day")
        }
    }

    private var pastDateButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
                pastDate = nil
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text(displayedDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                Image(systemName: "arrow.uturn.forward")
                    .font(.dmSans(.caption2))
            }
            .font(.dmSans(.subheadline))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Return to today")
    }

    private func dayNavigationButton(systemName: String, delta: Int, label: String) -> some View {
        Button {
            shiftDay(delta)
        } label: {
            Image(systemName: systemName)
                .font(.dmSans(.subheadline, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(navigationTarget(for: delta) == nil)
        .accessibilityLabel(label)
    }

    private func shiftDay(_ delta: Int) {
        guard let target = navigationTarget(for: delta) else { return }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let newPastDate: Date? = target >= todayStart ? nil : target
        if let oldDate = pastDate, let newPastDate, calendar.isDate(oldDate, inSameDayAs: newPastDate) {
            return
        }
        guard pastDate != nil || newPastDate != nil else { return }

        withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
            pastDate = newPastDate
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func navigationTarget(for delta: Int) -> Date? {
        guard delta != 0, !plans.isEmpty else { return nil }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        guard let adjacentDay = calendar.date(byAdding: .day,
                                              value: delta,
                                              to: calendar.startOfDay(for: displayedDate)),
              adjacentDay <= todayStart else { return nil }

        if planContaining(adjacentDay) != nil {
            return adjacentDay
        }

        // A plan is only created when the app runs in a given month. If the app
        // skipped a month, one swipe crosses the gap instead of trapping the
        // user on the edge of the nearest stored plan.
        let adjacentMonthStart = calendar.leftMonthStart(for: adjacentDay)
        if delta < 0 {
            guard let previousPlan = plans
                .filter({ $0.monthStart < adjacentMonthStart })
                .max(by: { $0.monthStart < $1.monthStart }),
                  let nextMonth = calendar.date(byAdding: .month,
                                                value: 1,
                                                to: previousPlan.monthStart),
                  let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
                return nil
            }
            return lastDay
        }

        return plans
            .filter({ $0.monthStart > adjacentMonthStart && $0.monthStart <= todayStart })
            .min(by: { $0.monthStart < $1.monthStart })?
            .monthStart
    }

    private func planContaining(_ date: Date) -> MonthPlan? {
        plans.first {
            Calendar.current.isDate($0.monthStart, equalTo: date, toGranularity: .month)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateContext
                .frame(minHeight: 44, alignment: .leading)
                .padding(.bottom, AppSpacing.sm)

            heroAmount

            if let plan {
                statusChip(plan)
                    .padding(.top, AppSpacing.sm)

                momentumStrip(plan: plan)
                    .padding(.top, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: heroBlockHeight, alignment: .topLeading)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.lg)
    }

    @ViewBuilder
    private var heroAmount: some View {
        if let plan {
            let remaining = plan.remainingToday(on: balanceDate)
            HeroMoneyText(amount: remaining, size: heroSize, suffix: "left")
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .spring(duration: 0.4), value: remaining)
        } else {
            Text("$– left")
                .font(.dmSans(size: heroSize, weight: .semibold, relativeTo: .largeTitle))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Status chip

    // The chip reports yesterday's outcome — a fresh, daily-scale number
    // rather than the cumulative carryover (the hero already bakes that in).
    // Day 1 (and a perfectly on-budget yesterday) falls back to the daily rate.
    @ViewBuilder
    private func statusChip(_ plan: MonthPlan) -> some View {
        let delta = plan.yesterdayDelta(for: displayedDate)
        if isToday, let recalcNote {
            chip(recalcNote, textColor: .secondary, backgroundColor: Color.secondary.opacity(0.12))
        } else if isToday, plan.needsIncomeConfirmation(on: displayedDate) {
            incomeConfirmRow(plan)
        } else if let delta, delta > 0 {
            chip(
                "+\(delta.formatted(.currency(code: "USD"))) saved yesterday",
                textColor: .fern500,
                backgroundColor: .fern100
            )
        } else if let delta, delta < 0 {
            chip(
                "\(delta.formatted(.currency(code: "USD"))) over yesterday",
                textColor: .leftNegative,
                backgroundColor: .leftNegative.opacity(0.12)
            )
        } else {
            chip(
                "\(plan.dailyRate.formatted(.currency(code: "USD"))) \(isToday ? "budget today" : "daily budget")",
                textColor: .secondary,
                backgroundColor: Color.secondary.opacity(0.12)
            )
        }
    }

    // MARK: - Income confirmation

    // Rides in the status chip's slot, so it costs no new vertical space. Both
    // halves are capsules because the chip is this screen's established
    // "tappable pill" idiom — the question opens the editor, "Yes" accepts the
    // number the month inherited. Only ever shown to a variable earner; a fixed
    // earner said so during onboarding and is never asked.
    private func incomeConfirmRow(_ plan: MonthPlan) -> some View {
        let money = Decimal.FormatStyle.Currency(code: "USD").precision(.fractionLength(0))
        let amount = plan.monthlyIncome.formatted(money)

        let question = Button {
            isEditingIncome = true
        } label: {
            chip("Still expecting \(amount)?",
                 textColor: .secondary,
                 backgroundColor: Color.secondary.opacity(0.12))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change money expected this month, currently \(amount)")

        let confirm = Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
                plan.confirmIncome()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            chip("Yes", textColor: .fern500, backgroundColor: .fern100)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Keep \(amount) as the money expected this month")

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.sm) {
                question
                confirm
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                question
                confirm
            }
        }
    }

    // A mid-month correction rewrites the whole month's daily rate, so the hero
    // can drop hundreds in one animation. Unexplained, that reads as a bug —
    // this says what moved and what the rate is now.
    private func noteRecalculation(_ plan: MonthPlan) {
        guard Calendar.current.component(.day, from: .now) > 1 else { return }
        let money = Decimal.FormatStyle.Currency(code: "USD").precision(.fractionLength(0))
        let from = plan.monthStart.formatted(.dateTime.month(.abbreviated).day())
        recalcNote = "Recalculated from \(from) — \(plan.dailyRate.formatted(money))/day"
    }

    private func chip(_ text: String, textColor: Color, backgroundColor: Color) -> some View {
        Text(text)
            .font(.dmSans(.subheadline, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(textColor)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    // The hero includes rollover. This meter isolates the displayed day's
    // spending pace against that day's daily budget.
    private func momentumStrip(plan: MonthPlan) -> some View {
        let spent = plan.spent(on: displayedDate)

        return TodayMeter(spent: spent, dailyRate: plan.dailyRate)
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: spent)
    }

    // MARK: - Transactions

    private var transactionsSection: some View {
        List {
            ForEach(todayTransactions) { tx in
                Button {
                    activeSpendingSheet = ActiveSpendingSheet(transaction: tx)
                } label: {
                    transactionRow(tx)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color(uiColor: .systemBackground))
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
        .background(Color(uiColor: .systemBackground))
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
                .font(.dmSans(.body))
                .foregroundStyle(.secondary)
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
        addButton
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Add button

    // Logging spending is the only action this screen offers, so the button
    // carries no label — a 56pt circle in the bottom-right corner, where a
    // thumb already rests. The glyph is a fixed size rather than a scaled one:
    // it is an icon inside a fixed circle, and scaling it would clip.
    private var addButton: some View {
        Button {
            activeSpendingSheet = ActiveSpendingSheet()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: 56, height: 56)
                .background(Color.primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add spending")
    }

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
