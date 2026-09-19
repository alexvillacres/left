import SwiftUI
import SwiftData
import UIKit

struct TodayView: View {
    @Query(sort: \MonthPlan.monthStart, order: .reverse) private var plans: [MonthPlan]
    @State private var activeSpendingSheet: ActiveSpendingSheet?
    @State private var activeCatchUp: ActiveCatchUp?
    @State private var didHandleForcedCatchUp = false
    @State private var pastDate: Date? = nil
    @State private var activeIncomeSheet: ActiveIncomeSheet?
    @State private var recalcNote: String?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.setAddAction) private var setAddAction
    @Environment(\.clearAddAction) private var clearAddAction
    @ScaledMetric private var heroSize = 44
    // Scales so the block grows with the type inside it instead of clipping.
    @ScaledMetric private var heroBlockHeight: CGFloat = 220

    private struct ActiveSpendingSheet: Identifiable {
        let id = UUID()
        var transaction: Transaction?
    }

    private struct ActiveIncomeSheet: Identifiable {
        let id = UUID()
        let source: IncomeSource
    }

    private struct ActiveCatchUp: Identifiable {
        let id = UUID()
        let period: ClosedRange<Date>
        let transaction: Transaction?
        let isForcedPrompt: Bool
    }

    private struct DaySnapshot {
        let dailyRate: Decimal
        let remaining: Decimal
        let yesterdayDelta: Decimal?
        let transactions: [Transaction]
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
        let snapshot = plan.map(makeSnapshot)

        NavigationStack {
            VStack(spacing: 0) {
                heroSection(plan: plan, snapshot: snapshot)
                if let plan, isToday {
                    catchUpCard(for: plan)
                }
                transactionsSection(snapshot?.transactions ?? [])
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
        .fullScreenCover(item: $activeSpendingSheet) { sheet in
            if let plan {
                AddSpendingView(plan: plan, date: transactionDate, transaction: sheet.transaction)
            }
        }
        .fullScreenCover(item: $activeCatchUp) { catchUp in
            if let plan {
                CatchUpView(plan: plan,
                            period: catchUp.period,
                            transaction: catchUp.transaction) {
                    if catchUp.isForcedPrompt {
                        didHandleForcedCatchUp = true
                    }
                }
            }
        }
        .sheet(item: $activeIncomeSheet) { sheet in
            if let plan {
                IncomeSheet(plan: plan, source: sheet.source) { change in
                    if change.delta != 0 {
                        noteRecalculation(change)
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            // Session-scoped: the explanation is for the jump you just watched.
            recalcNote = nil
        }
        .onAppear {
            setAddAction(
                AddAction(
                    id: "today.add-spending",
                    accessibilityLabel: "Add spending",
                    perform: { activeSpendingSheet = ActiveSpendingSheet() }
                )
            )
        }
        .onDisappear {
            clearAddAction("today.add-spending")
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

            if isToday, let plan, let context = catchUpPeriod(for: plan) {
                Button {
                    activeCatchUp = ActiveCatchUp(period: context.range,
                                                   transaction: context.transaction,
                                                   isForcedPrompt: context.isForcedPrompt)
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.dmSans(.subheadline, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Catch up spending")
                .accessibilityHint("Add one total for spending not already logged")
            }

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
        HapticFeedback.lightImpact()
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

    private func heroSection(plan: MonthPlan?, snapshot: DaySnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            dateContext
                .frame(minHeight: 44, alignment: .leading)
                .padding(.bottom, AppSpacing.sm)

            heroAmount(snapshot: snapshot)

            if let plan, let snapshot {
                statusChip(plan, snapshot: snapshot)
                    .padding(.top, AppSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: heroBlockHeight, alignment: .topLeading)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.lg)
    }

    @ViewBuilder
    private func heroAmount(snapshot: DaySnapshot?) -> some View {
        if let snapshot {
            HeroMoneyText(amount: snapshot.remaining, size: heroSize, suffix: "left")
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .spring(duration: 0.4), value: snapshot.remaining)
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
    private func statusChip(_ plan: MonthPlan, snapshot: DaySnapshot) -> some View {
        if isToday, let recalcNote {
            chip(recalcNote, textColor: .secondary, backgroundColor: .leftNeutralFill)
        } else if isToday,
                  let source = plan.unconfirmedIncomeSources(on: displayedDate).first {
            incomeConfirmRow(source)
        } else if let delta = snapshot.yesterdayDelta, delta > 0 {
            chip(
                "+\(delta.formatted(.currency(code: "USD"))) left from yesterday",
                textColor: .leftPositive,
                backgroundColor: .leftPositiveFill
            )
        } else if let delta = snapshot.yesterdayDelta, delta < 0 {
            chip(
                "\(delta.formatted(.currency(code: "USD"))) over yesterday",
                textColor: .leftNegative,
                backgroundColor: .leftNegativeFill
            )
        } else {
            chip(
                "\(snapshot.dailyRate.formatted(.currency(code: "USD"))) \(isToday ? "budget today" : "daily budget")",
                textColor: .secondary,
                backgroundColor: .leftNeutralFill
            )
        }
    }

    // MARK: - Income confirmation

    // Rides in the status chip's slot, so it costs no new vertical space. Both
    // halves are capsules because the chip is this screen's established
    // "tappable pill" idiom — the question opens the editor, "Yes" accepts the
    // number the source inherited. Sources are ordered largest first; affirming
    // one naturally advances this same slot to the next variable source.
    private func incomeConfirmRow(_ source: IncomeSource) -> some View {
        let money = Decimal.FormatStyle.Currency(code: "USD").precision(.fractionLength(0))
        let amount = source.amount.formatted(money)

        let question = Button {
            activeIncomeSheet = ActiveIncomeSheet(source: source)
        } label: {
            chip("Still expecting \(amount) from \(source.name)?",
                 textColor: .secondary,
                 backgroundColor: .leftNeutralFill)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change \(source.name) income, currently \(amount)")

        let confirm = Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
                source.affirmedAt = .now
            }
            HapticFeedback.lightImpact()
        } label: {
            chip("Yes", textColor: .leftPositive, backgroundColor: .leftPositiveFill)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Keep \(amount) expected from \(source.name)")

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

    // Name the source and direction behind the hero's numeric transition.
    private func noteRecalculation(_ change: IncomeChange) {
        let money = Decimal.FormatStyle.Currency(code: "USD").precision(.fractionLength(0))
        let sign = change.delta > 0 ? "+" : "−"
        recalcNote = "\(sign)\(abs(change.delta).formatted(money)) \(change.sourceName) · budget updated"
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

    // MARK: - Catch up

    private struct CatchUpPeriod {
        let range: ClosedRange<Date>
        let shouldPrompt: Bool
        let transaction: Transaction?
        let isForcedPrompt: Bool
    }

    private func catchUpPeriod(for plan: MonthPlan) -> CatchUpPeriod? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        if forcesCatchUpPrompt && !didHandleForcedCatchUp {
            let start = calendar.date(byAdding: .day, value: -2, to: yesterday)!
            let range = start...yesterday
            let catchUp = plan.transactions.first {
                $0.isCatchUp && $0.catchUpStartDate.map(calendar.startOfDay) == range.lowerBound &&
                $0.catchUpEndDate.map(calendar.startOfDay) == range.upperBound
            }
            return CatchUpPeriod(range: range,
                                 shouldPrompt: true,
                                 transaction: catchUp,
                                 isForcedPrompt: true)
        }

        let planStart = max(calendar.startOfDay(for: plan.effectiveCreatedAt), plan.monthStart)
        guard planStart <= yesterday else { return nil }

        let latestLoggedDay = plan.transactions.compactMap { transaction -> Date? in
            if transaction.isCatchUp, let end = transaction.catchUpEndDate {
                return min(calendar.startOfDay(for: end), yesterday)
            }
            guard transaction.date < today else { return nil }
            return calendar.startOfDay(for: transaction.date)
        }.max()
        let acknowledged = plan.catchUpAcknowledgedThrough.map { calendar.startOfDay(for: $0) }
        let coveredThrough = [latestLoggedDay, acknowledged].compactMap { $0 }.max()
        let firstUncovered = coveredThrough.flatMap {
            calendar.date(byAdding: .day, value: 1, to: $0)
        } ?? planStart
        // When every prior day is already covered, the permanent action still
        // opens a useful one-day flow for an extra amount the user remembers.
        let rangeStart = min(max(firstUncovered, planStart), yesterday)
        let missedDays = max(0, calendar.dateComponents([.day], from: rangeStart, to: yesterday).day ?? 0) + 1
        let range = rangeStart...yesterday
        let catchUp = plan.transactions.first {
            $0.isCatchUp && $0.catchUpStartDate.map(calendar.startOfDay) == range.lowerBound &&
            $0.catchUpEndDate.map(calendar.startOfDay) == range.upperBound
        }
        return CatchUpPeriod(range: range,
                             shouldPrompt: firstUncovered <= yesterday && missedDays >= 3,
                             transaction: catchUp,
                             isForcedPrompt: false)
    }

    private var forcesCatchUpPrompt: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-showCatchUpPrompt")
#else
        false
#endif
    }

    @ViewBuilder
    private func catchUpCard(for plan: MonthPlan) -> some View {
        if let context = catchUpPeriod(for: plan), context.shouldPrompt {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.dmSans(.title3)).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Anything to catch up on?")
                            .font(.dmSans(.subheadline, weight: .semibold))
                        Text("No spending logged since \(context.range.lowerBound.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).")
                            .font(.dmSans(.footnote)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button {
                        acknowledge(context.range, in: plan)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.dmSans(.caption, weight: .semibold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Dismiss catch-up prompt")
                }
                HStack(spacing: AppSpacing.lg) {
                    Button {
                        activeCatchUp = ActiveCatchUp(period: context.range,
                                                      transaction: context.transaction,
                                                      isForcedPrompt: context.isForcedPrompt)
                    } label: {
                        Text(context.transaction == nil ? "Add a total" : "Edit total")
                            .font(.dmSans(.subheadline, weight: .semibold))
                    }
                    .buttonStyle(.plain).foregroundStyle(Color.primary)
                    Button { acknowledge(context.range, in: plan) } label: {
                        Text("Nothing spent").font(.dmSans(.subheadline, weight: .medium))
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityHint("Marks the period as having no spending")
                }
            }
            .padding(AppSpacing.lg)
            .background(Color.leftNeutralFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, AppSpacing.xl).padding(.bottom, AppSpacing.md)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func acknowledge(_ period: ClosedRange<Date>, in plan: MonthPlan) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
            if forcesCatchUpPrompt {
                didHandleForcedCatchUp = true
            }
            plan.catchUpAcknowledgedThrough = max(plan.catchUpAcknowledgedThrough ?? .distantPast,
                                                  period.upperBound)
        }
        try? modelContext.save()
        HapticFeedback.lightImpact()
    }

    // MARK: - Transactions

    private func transactionsSection(_ transactions: [Transaction]) -> some View {
        List {
            ForEach(transactions) { tx in
                Button {
                    if tx.isCatchUp, let start = tx.catchUpStartDate, let end = tx.catchUpEndDate {
                        activeCatchUp = ActiveCatchUp(period: start...end,
                                                      transaction: tx,
                                                      isForcedPrompt: false)
                    } else {
                        activeSpendingSheet = ActiveSpendingSheet(transaction: tx)
                    }
                } label: {
                    transactionRow(tx)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color(uiColor: .systemBackground))
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
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemBackground))
    }

    private func transactionRow(_ tx: Transaction) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: tx.isCatchUp ? "arrow.uturn.backward.circle" : tx.category.symbol)
                .font(.dmSans(.body))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            if tx.isCatchUp, let start = tx.catchUpStartDate, let end = tx.catchUpEndDate {
                Text("Catch-up · \(catchUpLabel(start: start, end: end))")
                    .font(.dmSans(.body, weight: .medium))
            } else if let note = tx.note, !note.isEmpty {
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
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func catchUpLabel(start: Date, end: Date) -> String {
        let startText = start.formatted(.dateTime.month(.abbreviated).day())
        let endText = end.formatted(.dateTime.month(.abbreviated).day())
        return startText == endText ? startText : "\(startText)–\(endText)"
    }

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        HapticFeedback.lightImpact()
    }

    // Resolve the displayed day's numbers in one pass. Accessing the SwiftData
    // relationship can fault its contents into memory, so keeping all of the
    // transaction-derived UI together avoids repeating that work per render.
    private func makeSnapshot(for plan: MonthPlan) -> DaySnapshot {
        let calendar = Calendar.current
        let rate = plan.dailyRate
        let startOfDisplayedDay = calendar.startOfDay(for: displayedDate)
        let startOfPreviousDay = calendar.date(byAdding: .day, value: -1, to: startOfDisplayedDay)

        var spentAsOfBalance: Decimal = 0
        var spentOnPreviousDay: Decimal = 0
        var displayedTransactions: [Transaction] = []

        for transaction in plan.transactions {
            if transaction.date <= balanceDate {
                spentAsOfBalance += transaction.amount
            }
            if calendar.isDate(transaction.date, inSameDayAs: displayedDate) {
                displayedTransactions.append(transaction)
            }
            if let startOfPreviousDay,
               transaction.date >= startOfPreviousDay,
               transaction.date < startOfDisplayedDay {
                spentOnPreviousDay += transaction.amount
            }
        }

        displayedTransactions.sort { $0.date > $1.date }

        return DaySnapshot(
            dailyRate: rate,
            remaining: plan.remainingToday(on: balanceDate,
                                           spentAsOf: spentAsOfBalance,
                                           calendar: calendar),
            yesterdayDelta: plan.yesterdayDelta(for: displayedDate,
                                                spentOnPreviousDay: spentOnPreviousDay,
                                                calendar: calendar),
            transactions: displayedTransactions
        )
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
    let plan = MonthPlan(monthStart: start, monthlyIncome: 0, savingsGoal: 1000)
    container.mainContext.insert(plan)
    plan.incomeSources.append(IncomeSource(name: "Salary", amount: 4700, cadence: .fixed, affirmedAt: .now))
    plan.incomeSources.append(IncomeSource(name: "Client X", amount: 1500, cadence: .variable))
    plan.fixedExpenses.append(FixedExpense(name: "Rent", amount: 1800))
    plan.transactions.append(Transaction(amount: 14.50, category: .food, note: "Lunch"))
    plan.transactions.append(Transaction(amount: 4.75, category: .coffee))
    return TodayView()
        .modelContainer(container)
}
