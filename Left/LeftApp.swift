//
//  LeftApp.swift
//  Left
//
//  Created by Alex Villacres on 7/2/26.
//

import SwiftUI
import SwiftData

@main
struct LeftApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MonthPlan.self,
            IncomeSource.self,
            SavingsGoal.self,
            FixedExpense.self,
            Transaction.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRoot()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct AppRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MonthPlan.monthStart) private var allPlans: [MonthPlan]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var onboardingPlan: MonthPlan?

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            MonthView()
                .tabItem { Label("Month", systemImage: "calendar") }
            planTab
                .tabItem { Label("Plan", systemImage: "slider.horizontal.3") }
        }
        .environment(\.font, .dmSans(.body))
        .tint(.leftPositive)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .fullScreenCover(item: $onboardingPlan) { plan in
            NavigationStack {
                PlanView(plan: plan, isOnboarding: true) {
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
            if !hasCompletedOnboarding {
                onboardingPlan = plan
            }
        } else {
            hasCompletedOnboarding = false
            let plan = MonthPlan(monthStart: start, monthlyIncome: 0, savingsGoal: 0)
            modelContext.insert(plan)
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
}
