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
        .environment(\.font, .figtree(.body))
        .tint(.budgetPrimaryAction)
        .background(Color.budgetBackground.ignoresSafeArea())
        .fullScreenCover(item: $onboardingPlan) { plan in
            NavigationStack {
                PlanView(plan: plan, isOnboarding: true)
            }
        }
        .task { ensurePlan() }
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
        guard currentPlan == nil else { return }

        if let last = allPlans.last {
            let plan = nextPlan(from: last, for: start)
            modelContext.insert(plan)
        } else {
            let plan = MonthPlan(monthStart: start, monthlyIncome: 0, savingsGoal: 0)
            modelContext.insert(plan)
            onboardingPlan = plan
        }
    }

    private func nextPlan(from previous: MonthPlan, for monthStart: Date) -> MonthPlan {
        let calendar = Calendar.current
        let immediateNext = previous.nextMonth(calendar: calendar)
        if calendar.isDate(immediateNext.monthStart, equalTo: monthStart, toGranularity: .month) {
            return immediateNext
        }

        let plan = MonthPlan(monthStart: monthStart,
                             monthlyIncome: previous.monthlyIncome,
                             savingsGoal: previous.savingsGoal)
        plan.fixedExpenses = previous.fixedExpenses.map {
            FixedExpense(name: $0.name, amount: $0.amount, cadence: $0.effectiveCadence)
        }
        return plan
    }
}
