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
        Result { try ModelContainer(for: schema, configurations: [configuration]) }
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
    private static let addActionIDs: Set<String> = [
        "today.add-spending",
        "plan.income.add",
        "plan.fixed-expenses.add",
        "plan.savings.add",
    ]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MonthPlan.monthStart) private var allPlans: [MonthPlan]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var onboardingPlan: MonthPlan?
    @State private var selectedTab: AppTab = .today
    @State private var addAction: AddAction?

    var body: some View {
        // Deliberately not a TabView. TabView does not propagate a bottom
        // safeAreaInset into its children, so the capsule drew on top of list
        // content. Stacking the chrome under the screen makes the clearance a
        // plain layout fact. The cost is that a
        // tab switch resets that screen's navigation path — acceptable here,
        // where the screens are one level deep and Today is where you live.
        VStack(spacing: 0) {
            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selection: $selectedTab, addAction: addAction)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)
        }
        .environment(\.setAddAction) { action in
            assert(
                action.map { Self.addActionIDs.contains($0.id) } ?? true,
                "Only Today and the three Plan editors may supply a navigation add action."
            )
            addAction = action
        }
        .environment(\.clearAddAction) { id in
            // An outgoing destination can disappear after the incoming one
            // has appeared. Only let it clear the action it installed.
            if addAction?.id == id {
                addAction = nil
            }
        }
        .environment(\.font, .dmSans(.body))
        .tracking(BudgetTypography.appTracking)
        .tint(.leftAccent)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
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
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { ensurePlan() }
        }
        .onChange(of: selectedTab) {
            // A destination installs its own action on appearance. Clearing
            // first prevents an outgoing tab's closure from leaking into the
            // fixed slot while the next destination is being installed.
            addAction = nil
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedTab {
        case .today: TodayView()
        case .month: MonthView()
        case .plan: planTab
        case .settings: SettingsView()
        }
    }

    @ViewBuilder
    private var planTab: some View {
        if let plan = currentPlan ?? allPlans.last {
            NavigationStack { PlanView(plan: plan) }
        } else {
            Text("No plan yet")
                .foregroundStyle(.secondary)
        }
    }

    private var currentPlan: MonthPlan? {
        allPlans.first { Calendar.current.isDate($0.monthStart, equalTo: currentMonthStart, toGranularity: .month) }
    }

    private var currentMonthStart: Date {
        Calendar.current.leftMonthStart(for: .now)
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
