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

    // The flat dollar goal. Still holds the last flat value while the plan is
    // on a percentage target, so switching back restores what you had.
    var savingsGoal: Decimal

    // Non-nil means savings scale with income at this percent (0...100).
    // Optional so existing plans migrate straight to the flat-amount target.
    var savingsPercent: Decimal?

    // Whether the user earns the same every month or not. Optional so plans
    // written before this existed migrate to `.fixed` — the quiet default,
    // which never prompts. See `effectiveIncomeCadence`.
    var incomeCadence: IncomeCadence?

    // When the user last vouched for this month's income. Nil on a plan cloned
    // forward from last month: that number is inherited, not affirmed.
    var incomeConfirmedAt: Date?

    // When this record was made, which is not the same as when its month
    // started — install on the 14th and the plan is a day old in a half-spent
    // month. Windows count from here. Optional for migration.
    var createdAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \FixedExpense.plan)
    var fixedExpenses: [FixedExpense] = []

    @Relationship(deleteRule: .cascade, inverse: \Transaction.plan)
    var transactions: [Transaction] = []

    init(monthStart: Date,
         monthlyIncome: Decimal,
         savingsGoal: Decimal,
         savingsPercent: Decimal? = nil,
         incomeCadence: IncomeCadence? = nil,
         createdAt: Date? = .now) {
        self.monthStart = Calendar.current.leftMonthStart(for: monthStart)
        self.monthlyIncome = monthlyIncome
        self.savingsGoal = savingsGoal
        self.savingsPercent = savingsPercent
        self.incomeCadence = incomeCadence
        self.createdAt = createdAt
    }

    // Clone settings forward when a new month begins. Income, expenses and the
    // savings target all carry; `incomeConfirmedAt` deliberately does not — an
    // inherited number has not been vouched for yet.
    func nextMonth(calendar: Calendar = .current) -> MonthPlan {
        let start = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        let plan = MonthPlan(monthStart: start,
                             monthlyIncome: monthlyIncome,
                             savingsGoal: savingsGoal,
                             savingsPercent: savingsPercent,
                             incomeCadence: incomeCadence)
        plan.fixedExpenses = fixedExpenses.map {
            FixedExpense(name: $0.name, amount: $0.amount, cadence: $0.effectiveCadence)
        }
        return plan
    }
}

// MARK: - Income cadence
// Declared once during onboarding. A fixed earner is never asked to confirm
// income again; a variable earner is asked at the start of every month.

enum IncomeCadence: String, Codable, CaseIterable, Identifiable {
    case fixed, variable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fixed: "About the same"
        case .variable: "It varies"
        }
    }

    var detail: String {
        switch self {
        case .fixed: "Salary, retainers, or anything steady enough that you'd type the same number twice."
        case .variable: "Freelance, commission, or hourly. We'll ask what you expect to receive each month."
        }
    }

    var symbol: String {
        switch self {
        case .fixed: "equal"
        case .variable: "chart.line.uptrend.xyaxis"
        }
    }
}

extension MonthPlan {
    // How long a freshly inherited income stays open for confirmation.
    static let incomeConfirmWindowDays = 7

    // Nil means the plan predates the cadence choice. Treat those as fixed:
    // they were set up under a model that never asked, so asking now would be
    // a prompt about a month already underway.
    var effectiveIncomeCadence: IncomeCadence {
        incomeCadence ?? .fixed
    }

    var effectiveCreatedAt: Date {
        createdAt ?? monthStart
    }

    func daysSinceCreated(on date: Date = .now, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: effectiveCreatedAt)
        let to = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    // The confirm row exists only for a variable earner, only while the income
    // is inherited rather than affirmed, and only for the plan's first week.
    // After that it retires quietly — PlanView keeps the recovery path.
    func needsIncomeConfirmation(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard effectiveIncomeCadence == .variable,
              incomeConfirmedAt == nil,
              monthlyIncome > 0 else { return false }
        let elapsed = daysSinceCreated(on: date, calendar: calendar)
        return elapsed >= 0 && elapsed < Self.incomeConfirmWindowDays
    }

    // True once the window has closed on an income nobody ever vouched for.
    // Drives the quiet note in PlanView, which never expires.
    var incomeIsUnconfirmed: Bool {
        effectiveIncomeCadence == .variable && incomeConfirmedAt == nil && monthlyIncome > 0
    }

    @discardableResult
    func confirmIncome(_ newValue: Decimal? = nil, on date: Date = .now) -> Bool {
        let changed = newValue.map { $0 != monthlyIncome } ?? false
        if let newValue {
            monthlyIncome = max(0, newValue)
        }
        incomeConfirmedAt = date
        return changed
    }
}

// MARK: - Savings target
// A flat amount is right for "I owe my Roth $583 a month". A percentage is
// right for variable income — it scales with the month instead of eating the
// whole daily budget in a lean one.

enum SavingsTarget: Equatable {
    case amount(Decimal)
    case percentOfIncome(Decimal)
}

extension MonthPlan {
    static let maxSavingsPercent: Decimal = 100

    var savingsTarget: SavingsTarget {
        get {
            if let savingsPercent {
                .percentOfIncome(savingsPercent)
            } else {
                .amount(savingsGoal)
            }
        }
        set {
            switch newValue {
            case .amount(let value):
                savingsGoal = max(0, value)
                savingsPercent = nil
            case .percentOfIncome(let percent):
                savingsPercent = min(max(0, percent), Self.maxSavingsPercent)
            }
        }
    }

    var usesPercentSavings: Bool {
        savingsPercent != nil
    }

    // Dollars set aside this month, whichever shape the target takes.
    // This is what the budget math consumes — nothing else reads savingsGoal.
    var savingsAmount: Decimal {
        switch savingsTarget {
        case .amount(let value):
            max(0, value)
        case .percentOfIncome(let percent):
            (monthlyIncome * percent / 100).roundedToCents()
        }
    }

    // Switching modes shouldn't move the number under the user. Going to
    // percent, keep the equivalent share of income; going to amount, keep the
    // dollars currently resolved.
    func equivalentPercent(fallback: Decimal = 20) -> Decimal {
        guard monthlyIncome > 0, savingsGoal > 0 else { return fallback }
        let percent = (savingsGoal / monthlyIncome * 100).rounded(scale: 0)
        return min(max(percent, 0), Self.maxSavingsPercent)
    }
}

extension Decimal {
    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }

    func roundedToCents() -> Decimal {
        rounded(scale: 2)
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
        monthlyIncome - fixedTotal - savingsAmount
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

    func spent(on date: Date, calendar: Calendar = .current) -> Decimal {
        transactions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
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

    // Shown as the "+$12 saved yesterday" chip: yesterday's daily budget
    // minus what yesterday actually cost. Nil on day 1 — there is no
    // yesterday in this month to report on.
    func yesterdayDelta(for date: Date = .now, calendar: Calendar = .current) -> Decimal? {
        let day = calendar.component(.day, from: date)
        guard day > 1 else { return nil }
        let startOfToday = calendar.startOfDay(for: date)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let spentYesterday = transactions
            .filter { $0.date >= startOfYesterday && $0.date < startOfToday }
            .reduce(0) { $0 + $1.amount }
        return dailyRate - spentYesterday
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
        return savingsAmount + (monthlySpendable - projectedSpend)
    }
}

extension Calendar {
    func leftMonthStart(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return startOfDay(for: self.date(from: components)!)
    }
}
