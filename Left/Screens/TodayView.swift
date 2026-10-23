import SwiftUI
import SwiftData
import UIKit

struct TodayView: View {
    @Query(sort: \MonthPlan.monthStart, order: .reverse) private var plans: [MonthPlan]
    @State private var activeSpendingSheet: ActiveSpendingSheet?
    @State private var activeCatchUp: ActiveCatchUp?
    @State private var isShowingBalance = false
    @State private var balanceBreakdownHeight: CGFloat = 0
    @State private var pastDate: Date? = nil
    @State private var hasStartedAddButtonEntrance = false
    @State private var isAddButtonExpanded = false
    @State private var isAddButtonOpaque = false
    @Namespace private var addSpendingMorph
    private static let addSpendingMorphID = "add-spending"
    var visitID: UUID = UUID()
    var animateAddButtonEntrance = false
    // Owned by the root so it can also cover the tab bar.
    var coversZoomCorners: Binding<Bool> = .constant(false)
    var onSetUpIncome: () -> Void = {}
    @Environment(\.deleteSpending) private var deleteSpending
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let addButtonSize: CGFloat = 56
    // HeroMoneyText's font already scales with Dynamic Type.
    private let heroSize: CGFloat = 44

    private struct ActiveSpendingSheet: Identifiable {
        let id = UUID()
        var transaction: Transaction?
    }

    private struct ActiveCatchUp: Identifiable {
        let id = UUID()
        let period: ClosedRange<Date>
        let transaction: Transaction?
    }

    private typealias DaySnapshot = BalanceDay

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
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    heroSection(plan: plan, snapshot: snapshot,
                                maxBreakdownHeight: geometry.size.height * 0.45)
                    VStack(spacing: 0) {
                        if let plan, isToday {
                            CatchUpCard(plan: plan, visitID: visitID) { period in
                                openCatchUp(period)
                            }
                            .padding(.top, AppSpacing.sm)
                        }
                        if let snapshot, snapshot.transactions.isEmpty {
                            emptySpendingState(needsIncomeSetup: plan?.needsIncomeSetup ?? false)
                        } else {
                            transactionsSection(snapshot?.transactions ?? [], crossingEntry: snapshot?.crossingEntry)
                        }
                    }
                    .screenContent()
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            .accessibilityAction(named: "Previous day") {
                shiftDay(-1)
            }
            .accessibilityAction(named: "Next day") {
                shiftDay(1)
            }
            .overlay(alignment: .bottomTrailing) {
                if plan != nil {
                    addSpendingButton
                }
            }
            .background(Color.leftBackground.ignoresSafeArea())
        }
        .onChange(of: activeSpendingSheet?.id) { _, id in
            if id == nil { coversZoomCorners.wrappedValue = false }
        }
        .fullScreenCover(item: $activeSpendingSheet) { sheet in
            if let plan {
                AddSpendingView(plan: plan, date: transactionDate, transaction: sheet.transaction)
                // Editing opens from a list row, which is not the morph source.
                .morphDestination(id: Self.addSpendingMorphID,
                                  in: addSpendingMorph,
                                  active: sheet.transaction == nil && !reduceMotion)
            }
        }
        .fullScreenCover(item: $activeCatchUp) { catchUp in
            if let plan {
                CatchUpView(plan: plan,
                            period: catchUp.period,
                            transaction: catchUp.transaction)
            }
        }
    }

    // MARK: - Date

    @ViewBuilder
    private var periodRow: some View {
        PeriodNavigationRow(
            stepper: PeriodStepper(previousLabel: "Previous day",
                                   nextLabel: "Next day",
                                   canGoPrevious: navigationTarget(for: -1) != nil,
                                   canGoNext: navigationTarget(for: 1) != nil,
                                   onPrevious: { shiftDay(-1) },
                                   onNext: { shiftDay(1) })
        ) {
            PeriodPill(
                label: dayLabel(displayedDate),
                isEnabled: selectableDays.count > 1,
                cornerRadius: AppSpacing.xs,
                accessibilityLabel: isToday
                    ? "Today, \(displayedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))"
                    : displayedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                accessibilityHint: "Choose another day this month"
            ) {
                if !isToday {
                    Button("Return to Today") { selectDay(.now) }
                    Divider()
                }
                ForEach(selectableDays, id: \.self) { day in
                    Button {
                        selectDay(day)
                    } label: {
                        if Calendar.current.isDate(day, inSameDayAs: displayedDate) {
                            Label(dayLabel(day), systemImage: "checkmark")
                        } else {
                            Text(dayLabel(day))
                        }
                    }
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    // The days the pill can reach: this plan's month up to today, newest first.
    private var selectableDays: [Date] {
        guard let plan else { return [] }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        guard let range = calendar.range(of: .day, in: .month, for: plan.monthStart) else { return [] }

        return range.compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset - 1, to: plan.monthStart) else {
                return nil
            }
            let start = calendar.startOfDay(for: day)
            return start <= todayStart ? start : nil
        }
        .reversed()
    }

    private func selectDay(_ day: Date) {
        let calendar = Calendar.current
        guard !calendar.isDate(day, inSameDayAs: displayedDate) else { return }
        let todayStart = calendar.startOfDay(for: .now)

        withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
            pastDate = day >= todayStart ? nil : day
        }
        HapticFeedback.lightImpact()
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
        // skipped a month, one step crosses the gap instead of trapping the
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

    private func heroSection(plan: MonthPlan?, snapshot: DaySnapshot?,
                             maxBreakdownHeight: CGFloat) -> some View {
        let overspent = plan.map { !$0.needsIncomeSetup } == true && isOverspent(snapshot)
        return ScreenHeader {
            periodRow

            if let plan, plan.needsIncomeSetup {
                incomeSetup(plan)
                    .padding(.top, AppSpacing.sm)
            } else {
                heroAmount(snapshot: snapshot)
                    // Expanding the explanation must not compress the headline.
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.xxl)

                if overspent, let plan, let snapshot {
                    Text(overspentCaption(plan: plan, snapshot: snapshot))
                        .font(.dmSans(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, AppSpacing.xxs)
                }

                if let snapshot {
                    // Grow the ground to move spending down. At larger text
                    // sizes, scroll the explanation so spending stays reachable.
                    ScrollView {
                        balanceBreakdown(snapshot)
                            .fixedSize(horizontal: false, vertical: true)
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(key: BalanceBreakdownHeightKey.self,
                                                           value: geometry.size.height)
                                }
                            }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(height: isShowingBalance ? min(balanceBreakdownHeight, maxBreakdownHeight) : 0)
                    .opacity(isShowingBalance ? 1 : 0)
                    .accessibilityHidden(!isShowingBalance)
                    .padding(.top, isShowingBalance ? AppSpacing.xl : 0)
                    .padding(.bottom, isShowingBalance ? AppSpacing.sm : 0)
                    .onPreferenceChange(BalanceBreakdownHeightKey.self) { height in
                        balanceBreakdownHeight = height
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: overspent)
    }

    // Compare at display precision so a fractional-cent deficit that shows as
    // $0.00 never shows a negative state.
    private func isOverspent(_ snapshot: DaySnapshot?) -> Bool {
        snapshot?.isOver ?? false
    }

    private func overspentCaption(plan: MonthPlan, snapshot: DaySnapshot) -> String {
        plan.deficitCaption(for: snapshot)
    }

    private func balanceBreakdown(_ snapshot: DaySnapshot) -> some View {
        TodayBalanceSheet(day: snapshot)
    }

    @ViewBuilder
    private func heroAmount(snapshot: DaySnapshot?) -> some View {
        if let snapshot {
            Button {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.12)) {
                    isShowingBalance.toggle()
                }
            } label: {
                // "left" names the number now that there is no screen title;
                // the hero steps down a size before it would wrap.
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
                    // Only the state word takes the negative color.
                    HeroMoneyText(amount: snapshot.headlineAmount, size: heroSize,
                                  suffix: snapshot.isOver ? "over" : "left",
                                  suffixColor: snapshot.isOver ? .leftFeedbackNegative : .leftTextSecondary,
                                  suffixSizeRatio: 2.0 / 3.0)
                        .foregroundStyle(Color.leftTextPrimary)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: snapshot.remaining)

                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(snapshot.headlineAmount.formatted(.currency(code: "USD"))) \(snapshot.isOver ? "over" : "left")\(isToday ? (snapshot.isOver ? " today" : " to spend today") : " on " + snapshot.date.formatted(.dateTime.month(.wide).day()))")
            .accessibilityValue(isShowingBalance ? "Expanded" : "Collapsed")
            .accessibilityHint(isShowingBalance
                               ? "Hides the balance breakdown"
                               : "Shows the allowance, carried-forward balance, and logged spending based on your plan")
        } else {
            Text("$–")
                .font(.dmSans(size: heroSize, weight: .semibold, relativeTo: .largeTitle))
                .foregroundStyle(.secondary)
        }
    }

    private func incomeSetup(_ plan: MonthPlan) -> some View {
        let month = plan.monthStart.formatted(.dateTime.month(.wide))
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            (Text("$–") + Text(" left").font(.dmSans(size: heroSize * 2 / 3, relativeTo: .largeTitle)))
                .font(.dmSans(size: heroSize, weight: .semibold, relativeTo: .largeTitle))
                .foregroundStyle(Color.leftTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Daily balance unavailable, income incomplete")
            if Calendar.current.isDate(plan.monthStart, equalTo: .now, toGranularity: .month) {
                Button(action: onSetUpIncome) {
                    HStack(spacing: AppSpacing.xs) {
                        Text("Add \(month) income")
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .font(.dmSans(.subheadline, weight: .medium))
                    .padding(.horizontal, AppSpacing.md)
                    .frame(minHeight: 44)
                    .background(Color.leftNeutralFill, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text("Income wasn’t set for \(month).")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Catch up

    private func openCatchUp(_ period: CatchUpPeriod) {
        activeCatchUp = ActiveCatchUp(period: period.range,
                                      transaction: period.transaction)
    }

    // MARK: - Transactions

    private func emptySpendingState(needsIncomeSetup: Bool) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.sm) {
                Image("TodayEmptyState")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.leftAccent)
                    .frame(maxWidth: 288)
                    .accessibilityHidden(true)

                Text("No spending today")
                    .font(.dmSans(size: 16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(.primary)

                Text(isToday
                     ? (needsIncomeSetup
                        ? "Tap + to log spending."
                        : "Tap + to log spending. Unused allowance carries forward.")
                     : "There are no entries for this day.")
                    .font(.dmSans(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 250)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xxl * 2)
            .padding(.bottom, Self.addButtonSize + AppSpacing.xl * 2)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Today's one add action; it always means logging spending.
    private var addSpendingButton: some View {
        Button {
            activeSpendingSheet = ActiveSpendingSheet()
            blendZoomCorners()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.leftTextOnAccent)
                .frame(width: Self.addButtonSize, height: Self.addButtonSize)
                .background(Circle().fill(Color.leftAccent))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .morphSource(id: Self.addSpendingMorphID,
                     in: addSpendingMorph,
                     cornerRadius: Self.addButtonSize / 2,
                     active: !reduceMotion)
        .scaleEffect(addButtonVisibleImmediately || isAddButtonExpanded ? 1 : 0, anchor: .center)
        .opacity(addButtonVisibleImmediately || isAddButtonOpaque ? 1 : 0)
        .padding(AppSpacing.xl)
        .accessibilityLabel("Add spending")
        .onAppear {
            guard animateAddButtonEntrance, !reduceMotion,
                  !hasStartedAddButtonEntrance else { return }
            hasStartedAddButtonEntrance = true
            withAnimation(.smooth(duration: 0.14).delay(0.02)) {
                isAddButtonOpaque = true
            }
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82).delay(0.04)) {
                isAddButtonExpanded = true
            }
        }
    }

    // The system zoom keeps the cover clipped to the display's corner radius
    // until it settles, so light Today would show in the corners. Darken
    // behind it once the cover nearly fills the screen, then let go.
    private func blendZoomCorners() {
        guard !reduceMotion else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard activeSpendingSheet != nil else { return }
            withAnimation(.easeIn(duration: 0.12)) {
                coversZoomCorners.wrappedValue = true
            }
            try? await Task.sleep(for: .seconds(1))
            coversZoomCorners.wrappedValue = false
        }
    }

    private var addButtonVisibleImmediately: Bool {
        !animateAddButtonEntrance || reduceMotion
    }

    private func transactionsSection(_ transactions: [Transaction], crossingEntry: Transaction?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Spending")
                .font(.dmSans(.headline, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, AppSpacing.xl)

            transactionList(transactions, crossingEntry: crossingEntry)
        }
        .padding(.top, AppSpacing.xl)
    }

    private func transactionList(_ transactions: [Transaction], crossingEntry: Transaction?) -> some View {
        List {
            ForEach(transactions) { tx in
                Button {
                    if tx.isCatchUp, let start = tx.catchUpStartDate, let end = tx.catchUpEndDate {
                        activeCatchUp = ActiveCatchUp(period: start...end,
                                                      transaction: tx)
                    } else {
                        activeSpendingSheet = ActiveSpendingSheet(transaction: tx)
                    }
                } label: {
                    TransactionRow(transaction: tx, marksZeroCrossing: isShowingBalance && plan?.needsIncomeSetup == false && crossingEntry?.id == tx.id)
                        .padding(.horizontal, AppSpacing.xl)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.leftBackground)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteSpending(tx)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(Color.leftDestructiveFill)
                }
            }
        }
        .listStyle(.plain)
        // The last row scrolls clear of the add button.
        .contentMargins(.bottom, Self.addButtonSize + AppSpacing.xl * 2, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.leftBackground)
    }

    // Use the same model snapshot for the headline, explanation, and list.
    private func makeSnapshot(for plan: MonthPlan) -> DaySnapshot {
        plan.balanceDay(on: balanceDate)
    }
}

private struct BalanceBreakdownHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
