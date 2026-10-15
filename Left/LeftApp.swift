//
//  LeftApp.swift
//  Left
//
//  Created by Alex Villacres on 7/2/26.
//

import SwiftUI
import SwiftData

// Opening the store is the one operation that can fail before the app exists.
// It is deliberately not a fatalError: the realistic cause is a migration that
// cannot resolve, and that would brick every future launch with no way out but
// deleting the app. Falling back to an in-memory store would be worse still —
// the app would look normal while quietly discarding everything typed into it.
// So a failure surfaces as a screen that explains itself and offers the reset.
enum PersistentStore {
    static let schema = Schema([
        MonthPlan.self,
        IncomeSource.self,
        SavingsGoal.self,
        SavingsAllocation.self,
        FixedExpense.self,
        Transaction.self,
    ])

    static let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    static func load() -> Result<ModelContainer, Error> {
        Result {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            try backfillStableIDs(in: container)
            return container
        }
    }

    // Stable IDs were introduced after the first stores shipped. Keeping the
    // persisted column optional lets Core Data add it without manufacturing
    // one repeated default value for every existing row. This runs before the
    // container reaches SwiftUI, assigns each legacy object its own UUID, and
    // commits that one-time migration immediately.
    private static func backfillStableIDs(in container: ModelContainer) throws {
        let context = ModelContext(container)
        var changed = false

        for object in try context.fetch(FetchDescriptor<MonthPlan>()) where object.stableID == nil {
            object.stableID = UUID(); changed = true
        }
        for object in try context.fetch(FetchDescriptor<IncomeSource>()) where object.stableID == nil {
            object.stableID = UUID(); changed = true
        }
        for object in try context.fetch(FetchDescriptor<SavingsGoal>()) where object.stableID == nil {
            object.stableID = UUID(); changed = true
        }
        for object in try context.fetch(FetchDescriptor<SavingsAllocation>()) where object.stableID == nil {
            object.stableID = UUID(); changed = true
        }
        for object in try context.fetch(FetchDescriptor<FixedExpense>()) where object.stableID == nil {
            object.stableID = UUID(); changed = true
        }
        for object in try context.fetch(FetchDescriptor<Transaction>()) where object.stableID == nil {
            object.stableID = UUID(); changed = true
        }

        if changed { try context.save() }
    }

    // SQLite keeps its write-ahead log beside the store. Leaving those behind
    // can resurrect the same corrupt state, so the reset takes all three.
    static func erase() {
        let store = configuration.url
        let directory = store.deletingLastPathComponent()
        let sidecars = ["-shm", "-wal"].map {
            directory.appendingPathComponent(store.lastPathComponent + $0)
        }

        for url in [store] + sidecars {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

@main
struct LeftApp: App {
    @State private var store = PersistentStore.load()

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                AppRoot()
                    .modelContainer(container)
            case .failure(let error):
                StoreRecoveryView(error: error, retry: reload, reset: resetStore)
            }
        }
    }

    private func reload() {
        store = PersistentStore.load()
    }

    private func resetStore() {
        PersistentStore.erase()
        store = PersistentStore.load()
    }
}

struct AppRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MonthPlan.monthStart) private var allPlans: [MonthPlan]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Start of the most recent week whose report was shown or skipped.
    @AppStorage("weeklyReportWeekStart") private var reportedWeekStart: Double = 0
    @State private var onboardingPlan: MonthPlan?
    @State private var weeklyReport: WeeklyReport?
    @State private var selectedTab: AppTab = .today
    @State private var todayVisitID = UUID()
    @State private var animateTodayAddButtonOnEntry = false
    @State private var coversZoomCorners = false
    @State private var tabDirection: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Activity and Plan show the same granularity, so they browse one month
    // together: stepping back in Activity and switching to Plan lands on that
    // month rather than snapping to the current one. nil means the current month.
    @State private var browsedMonth: Date?
    @State private var opensPlanIncome = false
    // The most recent swipe deletion, offered back for a few seconds.
    @State private var deletedSpending: DeletedSpending?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        // Deliberately not a TabView. Stacking the bar under the screen keeps
        // its custom styling and makes the clearance a plain layout fact. The
        // cost is that a tab switch resets that screen's navigation path — acceptable here,
        // where the screens are one level deep and Today is where you live.
        VStack(spacing: 0) {
            ZStack {
                currentScreen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(selectedTab)
                    .transition(tabTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(alignment: .bottom) { undoBar }
            .environment(\.deleteSpending, DeleteSpendingAction(perform: deleteSpending))

            AppTabBar(selection: Binding(
                get: { selectedTab },
                set: { selectTab($0) }
            ))
        }
        .overlay {
            Color.leftEntryBackground
                .ignoresSafeArea()
                .opacity(coversZoomCorners ? 1 : 0)
                .allowsHitTesting(false)
        }
        .overlay {
            if let weeklyReport {
                WeeklyReportView(report: weeklyReport) {
                    self.weeklyReport = nil
                }
            }
        }
        .environment(\.font, .dmSans(.body))
        .tracking(BudgetTypography.appTracking)
        .tint(.leftAccent)
        .background(Color.leftBackground.ignoresSafeArea())
        .fullScreenCover(item: $onboardingPlan) { plan in
            NavigationStack {
                OnboardingView(plan: plan) {
                    try? modelContext.save()
                    hasCompletedOnboarding = true
                    onboardingPlan = nil
                }
            }
        }
        .task {
            HapticFeedback.prepareLight()
            ensurePlan()
            presentWeeklyReportIfDue()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            ensurePlan()
            presentWeeklyReportIfDue()
        }
        .onChange(of: selectedTab) {
            if selectedTab != .plan { opensPlanIncome = false }
        }
    }

    private var tabTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        let motion = Animation.smooth(duration: 0.20)
        return .asymmetric(
            insertion: .offset(x: -28 * tabDirection)
                .combined(with: .opacity)
                .animation(motion),
            removal: .offset(x: tabRemovalOffset)
                .combined(with: .opacity)
                .animation(motion)
        )
    }

    // On Today the bar sits beside the add button, on the same line, so
    // neither covers the other.
    @ViewBuilder
    private var undoBar: some View {
        if let deletedSpending {
            UndoBar(deleted: deletedSpending) { undoDelete(deletedSpending) }
                .padding(.leading, AppSpacing.lg)
                .padding(.trailing, selectedTab == .today
                         ? AppSpacing.xl + TodayView.addButtonSize + AppSpacing.md
                         : AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .task(id: deletedSpending.id) {
                    try? await Task.sleep(for: .seconds(voiceOverEnabled ? 10 : 5))
                    guard !Task.isCancelled else { return }
                    withAnimation(.smooth(duration: 0.25)) { self.deletedSpending = nil }
                }
        }
    }

    private func deleteSpending(_ transaction: Transaction) {
        let deleted = DeletedSpending(transaction)
        modelContext.delete(transaction)
        HapticFeedback.lightImpact()
        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
            deletedSpending = deleted
        }
        AccessibilityNotification.Announcement(
            "Deleted \(deleted.title), \(deleted.amount.formatted(.currency(code: "USD"))). Undo available."
        ).post()
    }

    private func undoDelete(_ deleted: DeletedSpending) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
            deleted.restore()
            deletedSpending = nil
        }
        HapticFeedback.lightImpact()
    }

    private var tabRemovalOffset: CGFloat { 28 * tabDirection }

    private func selectTab(_ tab: AppTab) {
        guard tab != selectedTab else { return }
        let tabs = AppTab.allCases
        // Earlier tabs are to the left, so the outgoing screen slides right.
        tabDirection = (tabs.firstIndex(of: tab) ?? 0) < (tabs.firstIndex(of: selectedTab) ?? 0) ? 1 : -1
        #if DEBUG
        print("Tab \(selectedTab.title) → \(tab.title): removal x = \(tabRemovalOffset)")
        #endif
        if tab == .today {
            todayVisitID = UUID()
            animateTodayAddButtonOnEntry = true
        }
        selectedTab = tab
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedTab {
        case .today:
            TodayView(visitID: todayVisitID,
                      animateAddButtonEntrance: animateTodayAddButtonOnEntry,
                      coversZoomCorners: $coversZoomCorners) {
                browsedMonth = nil
                opensPlanIncome = true
                selectTab(.plan)
            }
        case .activity: ActivityView(browsedMonth: $browsedMonth)
        case .plan: planTab
        }
    }

    @ViewBuilder
    private var planTab: some View {
        if let plan = selectedPlan ?? currentPlan ?? allPlans.last {
            NavigationStack {
                PlanView(plan: plan, availablePlans: allPlans, onSelectMonth: { month in
                    browsedMonth = month == currentMonthStart ? nil : month
                    opensPlanIncome = false
                }, opensIncome: opensPlanIncome, onResetDemo: demoResetAction)
            }
            .id(plan.monthStart)
        } else {
            Text("No plan yet")
                .foregroundStyle(.secondary)
        }
    }

    private var selectedPlan: MonthPlan? {
        guard let browsedMonth else { return nil }
        return allPlans.first { $0.monthStart == browsedMonth }
    }

    private var currentPlan: MonthPlan? {
        allPlans.first { Calendar.current.isDate($0.monthStart, equalTo: currentMonthStart, toGranularity: .month) }
    }

    private var currentMonthStart: Date {
        Calendar.current.leftMonthStart(for: .now)
    }

    private var demoResetAction: (() throws -> Void)? {
#if DEBUG
        guard Bundle.main.bundleIdentifier == "com.villacres.left.demo" else { return nil }
        return { try resetDemo() }
#else
        return nil
#endif
    }

#if DEBUG
    private func resetDemo() throws {
        guard Bundle.main.bundleIdentifier == "com.villacres.left.demo" else { return }

        do {
            for transaction in try modelContext.fetch(FetchDescriptor<Transaction>()) {
                modelContext.delete(transaction)
            }
            for expense in try modelContext.fetch(FetchDescriptor<FixedExpense>()) {
                modelContext.delete(expense)
            }
            for allocation in try modelContext.fetch(FetchDescriptor<SavingsAllocation>()) {
                modelContext.delete(allocation)
            }
            for goal in try modelContext.fetch(FetchDescriptor<SavingsGoal>()) {
                modelContext.delete(goal)
            }
            for source in try modelContext.fetch(FetchDescriptor<IncomeSource>()) {
                modelContext.delete(source)
            }
            for plan in try modelContext.fetch(FetchDescriptor<MonthPlan>()) {
                modelContext.delete(plan)
            }

            let plan = MonthPlan(monthStart: currentMonthStart, monthlyIncome: 0, savingsGoal: 0)
            modelContext.insert(plan)
            try modelContext.save()

            hasCompletedOnboarding = false
            browsedMonth = nil
            opensPlanIncome = false
            selectedTab = .today
            onboardingPlan = plan
        } catch {
            modelContext.rollback()
            throw error
        }
    }
#endif

    // The first open of a new week shows last week's report once, whichever
    // day that is. Skipped weeks don't pile up: only the latest one counts.
    private func presentWeeklyReportIfDue(now: Date = .now) {
        guard hasCompletedOnboarding, onboardingPlan == nil, weeklyReport == nil else { return }
        let thisWeek = WeeklyReport.weekStart(containing: now)
        let lastWeek = WeeklyReport.calendar.date(byAdding: .day, value: -7, to: thisWeek)!

#if DEBUG
        // Launch with `-WeeklyReportPreview 58` to see any ticket on demand.
        if let preview = UserDefaults.standard.string(forKey: "WeeklyReportPreview"),
           let left = Decimal(string: preview) {
            weeklyReport = WeeklyReport(weekStart: lastWeek, allowance: left, spent: 0)
            return
        }
#endif

        guard lastWeek.timeIntervalSinceReferenceDate > reportedWeekStart else { return }

        // While Today is asking to catch up on days from last week, the total
        // is still incomplete. Wait until the gap is logged or acknowledged.
        if let currentPlan,
           let period = CatchUpPeriod.current(for: currentPlan, now: now),
           period.hasThreeQuietDays,
           period.range.lowerBound < thisWeek {
            return
        }

        reportedWeekStart = lastWeek.timeIntervalSinceReferenceDate
        guard let report = WeeklyReport.make(weekStart: lastWeek, plans: allPlans),
              WeeklyReportView.hasTicket(for: report) else { return }
        weeklyReport = report
    }

    private func ensurePlan() {
        let start = currentMonthStart
        if let currentPlan {
            materializeLegacyIncomeIfNeeded(in: currentPlan)
            materializeLegacySavingsIfNeeded(in: currentPlan)
            reconcileCarryover(into: currentPlan)
            if !hasCompletedOnboarding {
                onboardingPlan = currentPlan
            }
            return
        }

        if let last = allPlans.last {
            let plan = nextPlan(from: last, for: start)
            modelContext.insert(plan)
            materializeLegacyIncomeIfNeeded(in: plan)
            materializeLegacySavingsIfNeeded(in: plan)
            reconcileCarryover(into: plan)
            if !hasCompletedOnboarding {
                onboardingPlan = plan
            }
        } else {
            hasCompletedOnboarding = false
            let plan = MonthPlan(monthStart: start, monthlyIncome: 0, savingsGoal: 0)
            modelContext.insert(plan)
            materializeLegacySavingsIfNeeded(in: plan)
            reconcileCarryover(into: plan)
            onboardingPlan = plan
        }
    }

    private func nextPlan(from previous: MonthPlan, for monthStart: Date) -> MonthPlan {
        previous.clone(for: monthStart)
    }

    // Deliberately current-plan-only: past scalar plans remain untouched and
    // continue to read correctly through MonthPlan.incomeTotal's fallback.
    private func materializeLegacyIncomeIfNeeded(in plan: MonthPlan) {
        guard plan.incomeSources.isEmpty, plan.monthlyIncome > 0 else { return }
        let source = IncomeSource(name: "Income",
                                  amount: plan.monthlyIncome,
                                  cadence: plan.incomeCadence ?? .fixed,
                                  affirmedAt: plan.incomeConfirmedAt)
        plan.incomeSources.append(source)
        try? modelContext.save()
    }

    // Deliberately current-plan-only, matching income migration. Historical
    // plans continue to resolve through the legacy pair without being rewritten.
    private func materializeLegacySavingsIfNeeded(in plan: MonthPlan) {
        let hasLegacyTarget = plan.savingsGoal > 0 || (plan.savingsPercent ?? 0) > 0
        guard plan.savingsGoals.isEmpty, hasLegacyTarget else { return }
        let goal = SavingsGoal(name: "Savings",
                               amount: plan.savingsGoal,
                               percent: plan.savingsPercent)
        plan.savingsGoals.append(goal)
        try? modelContext.save()
    }

    // Only the current link is corrected here. A stale middle link in a longer
    // chain fixes itself if that month later becomes the current plan.
    private func reconcileCarryover(into plan: MonthPlan) {
        let previous = allPlans
            .filter { $0.monthStart < plan.monthStart }
            .max { $0.monthStart < $1.monthStart }
        let carriedGross = previous?.endingSurplus() ?? 0
        guard plan.carriedGross != carriedGross else { return }
        plan.carriedGross = carriedGross
        try? modelContext.save()
    }
}
