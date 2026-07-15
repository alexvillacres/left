import Foundation
import SwiftData

// MARK: - MonthPlan
// One record per calendar month. Snapshots income / expenses / savings
// so past months stay historically accurate when your income changes.

@Model
final class MonthPlan {
    // First day of the month, normalized to startOfDay. Unique per month.
    @Attribute(.unique) var monthStart: Date

    var monthlyIncome: Decimal
    var savingsGoal: Decimal

    @Relationship(deleteRule: .cascade, inverse: \FixedExpense.plan)
    var fixedExpenses: [FixedExpense] = []

    @Relationship(deleteRule: .cascade, inverse: \Transaction.plan)
    var transactions: [Transaction] = []

    init(monthStart: Date, monthlyIncome: Decimal, savingsGoal: Decimal) {
        self.monthStart = Calendar.current.leftMonthStart(for: monthStart)
        self.monthlyIncome = monthlyIncome
        self.savingsGoal = savingsGoal
    }

    // Clone settings forward when a new month begins.
    func nextMonth(calendar: Calendar = .current) -> MonthPlan {
        let start = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        let plan = MonthPlan(monthStart: start,
                             monthlyIncome: monthlyIncome,
                             savingsGoal: savingsGoal)
        plan.fixedExpenses = fixedExpenses.map {
            FixedExpense(name: $0.name, amount: $0.amount, cadence: $0.effectiveCadence)
        }
        return plan
    }
}

// MARK: - FixedExpense

@Model
final class FixedExpense {
    var name: String
    var amount: Decimal
    var cadence: ExpenseCadence?
    var plan: MonthPlan?

    init(name: String, amount: Decimal, cadence: ExpenseCadence = .monthly) {
        self.name = name
        self.amount = amount
        self.cadence = cadence
    }
}

enum ExpenseCadence: String, Codable, CaseIterable, Identifiable {
    case monthly, quarterly, annually

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .annually: "Annually"
        }
    }

    var divisorToMonthly: Decimal {
        switch self {
        case .monthly: 1
        case .quarterly: 3
        case .annually: 12
        }
    }
}

extension FixedExpense {
    var effectiveCadence: ExpenseCadence {
        cadence ?? .monthly
    }

    var monthlyAmount: Decimal {
        amount / effectiveCadence.divisorToMonthly
    }
}

// MARK: - Transaction

@Model
final class Transaction {
    var amount: Decimal
    var date: Date
    var category: Category
    var note: String?
    var plan: MonthPlan?

    init(amount: Decimal, date: Date = .now, category: Category = .other, note: String? = nil) {
        self.amount = amount
        self.date = date
        self.category = category
        self.note = note
    }
}

// Fixed set keeps the add-sheet to one row of chips. Codable enums
// store cleanly in SwiftData.
enum Category: String, Codable, CaseIterable, Identifiable {
    case coffee, food, grocery, bar, transit, shopping, household, fun, other
    var id: String { rawValue }

    static var allCases: [Category] {
        [.grocery, .bar, .food, .transit, .coffee, .household, .shopping, .other]
    }

    var label: String {
        switch self {
        case .coffee: "Coffee"
        case .food: "Food"
        case .grocery: "Grocery"
        case .bar: "Bar"
        case .transit: "Transit"
        case .shopping: "Shopping"
        case .household: "Household"
        case .fun: "Other"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .coffee:    "cup.and.saucer.fill"
        case .food:      "fork.knife"
        case .grocery:   "basket.fill"
        case .bar:       "wineglass.fill"
        case .transit:   "tram.fill"
        case .shopping:  "bag.fill"
        case .household: "house.fill"
        case .fun:       "circle.dashed"
        case .other:     "circle.dashed"
        }
    }
}

// MARK: - Derived math
// Everything on screen is computed from the plan + transactions.
// No stored rollover, no stored daily balances.

extension MonthPlan {
    var fixedTotal: Decimal {
        fixedExpenses.reduce(0) { $0 + $1.monthlyAmount }
    }

    // What's available for daily spending across the whole month.
    var monthlySpendable: Decimal {
        monthlyIncome - fixedTotal - savingsGoal
    }

    func daysInMonth(calendar: Calendar = .current) -> Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    var dailyRate: Decimal {
        monthlySpendable / Decimal(daysInMonth())
    }

    func spent(asOf date: Date = .now) -> Decimal {
        transactions
            .filter { $0.date <= date }
            .reduce(0) { $0 + $1.amount }
    }

    // The hero number. Rollover and overspend-borrowing fall out
    // of this formula automatically:
    //   allowance earned so far − everything spent so far
    func remainingToday(on date: Date = .now, calendar: Calendar = .current) -> Decimal {
        let day = calendar.component(.day, from: date)   // 1-based
        let earned = dailyRate * Decimal(day)
        return earned - spent(asOf: date)
    }

    // Shown as the "+$27 rolled over" chip: how far ahead (or behind)
    // you were entering today.
    func carryover(into date: Date = .now, calendar: Calendar = .current) -> Decimal {
        let day = calendar.component(.day, from: date)
        guard day > 1 else { return 0 }
        let startOfToday = calendar.startOfDay(for: date)
        let earnedThroughYesterday = dailyRate * Decimal(day - 1)
        let spentThroughYesterday = transactions
            .filter { $0.date < startOfToday }
            .reduce(0) { $0 + $1.amount }
        return earnedThroughYesterday - spentThroughYesterday
    }

    // Month screen: net position for the "you're $41 ahead" line.
    func netPosition(on date: Date = .now) -> Decimal {
        remainingToday(on: date) - dailyRate
    }

    // Projected savings if current pace holds: goal + whatever surplus
    // exists at month end. Powers the end-of-month summary.
    func projectedSavings(on date: Date = .now, calendar: Calendar = .current) -> Decimal {
        let day = calendar.component(.day, from: date)
        let remaining = daysInMonth() - day
        let pace = day > 0 ? spent(asOf: date) / Decimal(day) : 0
        let projectedSpend = spent(asOf: date) + pace * Decimal(remaining)
        return savingsGoal + (monthlySpendable - projectedSpend)
    }
}

extension Calendar {
    func leftMonthStart(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return startOfDay(for: self.date(from: components)!)
    }
}
