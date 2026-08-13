import Foundation
import SwiftData

// MARK: - MonthPlan
// One record per calendar month. Snapshots income / expenses / savings
// so past months stay historically accurate when your income changes.
// Rollover remains derived: carriedGross caches the prior plan's final position,
// carriedAllocated is the only stored money decision, and carryAnnouncedAt is
// bookkeeping so that decision is offered once.

@Model
final class MonthPlan {
    // First day of the month, normalized to startOfDay. Unique per month.
    @Attribute(.unique) var monthStart: Date

    // Legacy scalar income. New plans read sources; old plans use this only
    // through incomeTotal's fallback.
    var monthlyIncome: Decimal

    // The flat dollar goal. Still holds the last flat value while the plan is
    // on a percentage target, so switching back restores what you had.
    var savingsGoal: Decimal

    // Non-nil means savings scale with income at this percent (0...100).
    // Optional so existing plans migrate straight to the flat-amount target.
    var savingsPercent: Decimal?

    // Legacy plan-level cadence. New code reads cadence from IncomeSource.
    var incomeCadence: IncomeCadence?

    // Legacy plan-level affirmation timestamp. New code writes IncomeSource.
    var incomeConfirmedAt: Date?

    // When this record was made, which is not the same as when its month
    // started — install on the 14th and the plan is a day old in a half-spent
    // month. Windows count from here. Optional for migration.
    var createdAt: Date?

    // Recomputed on launch so later edits to history still flow forward.
    // Optional keeps stores from before cross-month carry readable as zero.
    var carriedGross: Decimal?

    // This survives reconciliation because only the user can decide that part
    // of an inherited surplus belongs in savings.
    var carriedAllocated: Decimal = 0

    // Delivery state belongs to this boundary, not to the plan template.
    // Optional keeps stores from before the month-open summary migratable.
    var carryAnnouncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \IncomeSource.plan)
    var incomeSources: [IncomeSource] = []

    @Relationship(deleteRule: .cascade, inverse: \SavingsGoal.plan)
    var savingsGoals: [SavingsGoal] = []

    @Relationship(deleteRule: .cascade, inverse: \SavingsAllocation.plan)
    var savingsAllocations: [SavingsAllocation] = []

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

    // The one clone path for both adjacent months and gaps. Per-source
    // affirmation deliberately does not carry: inherited variable income has
    // not been vouched for in the new month. All three carry fields also stay
    // at their defaults because carry is a boundary fact, not template data.
    func clone(for monthStart: Date) -> MonthPlan {
        let hasLegacyIncomeOnly = incomeSources.isEmpty
        let plan = MonthPlan(monthStart: monthStart,
                             monthlyIncome: hasLegacyIncomeOnly ? monthlyIncome : 0,
                             savingsGoal: savingsGoal,
                             savingsPercent: savingsPercent,
                             incomeCadence: hasLegacyIncomeOnly ? incomeCadence : nil)
        let targetMonth = Calendar.current.leftMonthStart(for: monthStart)
        plan.incomeSources = incomeSources.compactMap {
            guard $0.covers(month: targetMonth) else { return nil }
            return IncomeSource(name: $0.name,
                                amount: $0.amount,
                                cadence: $0.effectiveCadence,
                                startsOn: $0.startsOn,
                                endsAfter: $0.endsAfter)
        }
        plan.savingsGoals = savingsGoals.map {
            SavingsGoal(name: $0.name, amount: $0.amount, percent: $0.percent)
        }
        plan.fixedExpenses = fixedExpenses.compactMap {
            guard $0.covers(month: targetMonth) else { return nil }
            return FixedExpense(name: $0.name,
                                amount: $0.amount,
                                cadence: $0.effectiveCadence,
                                startsOn: $0.startsOn,
                                endsAfter: $0.endsAfter)
        }
        return plan
    }

    func nextMonth(calendar: Calendar = .current) -> MonthPlan {
        let start = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        return clone(for: start)
    }
}

// MARK: - Income cadence
// Stored per source: one plan can mix a steady salary with variable invoices.

enum IncomeCadence: String, Codable, CaseIterable, Identifiable {
    case fixed, variable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fixed: "About the same"
        case .variable: "It varies"
        }
    }

}

extension MonthPlan {
    // How long a freshly inherited income stays open for confirmation.
    static let incomeConfirmWindowDays = 7

    var effectiveCreatedAt: Date {
        createdAt ?? monthStart
    }

    func daysSinceCreated(on date: Date = .now, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: effectiveCreatedAt)
        let to = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    // The Today prompt exists only during a plan's first week. Plan keeps the
    // permanent recovery note for any variable source that was never affirmed.
    func unconfirmedIncomeSources(on date: Date = .now,
                                  calendar: Calendar = .current,
                                  withinWindow: Bool = true) -> [IncomeSource] {
        if withinWindow {
            let elapsed = daysSinceCreated(on: date, calendar: calendar)
            guard elapsed >= 0 && elapsed < Self.incomeConfirmWindowDays else { return [] }
        }

        return incomeSources
            .filter(\.isUnconfirmed)
            .sorted {
                if $0.amount == $1.amount { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                return $0.amount > $1.amount
            }
    }

    func needsIncomeConfirmation(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        let elapsed = daysSinceCreated(on: date, calendar: calendar)
        return elapsed >= 0
            && elapsed < Self.incomeConfirmWindowDays
            && incomeSources.contains(where: \.isUnconfirmed)
    }
}

// MARK: - Income source

@Model
final class IncomeSource {
    var name: String
    var amount: Decimal
    var cadence: IncomeCadence?
    var affirmedAt: Date?
    var startsOn: Date? {
        didSet {
            let normalized = startsOn.map { Calendar.current.leftMonthStart(for: $0) }
            if startsOn != normalized { startsOn = normalized }
        }
    }
    var endsAfter: Date? {
        didSet {
            let normalized = endsAfter.map { Calendar.current.leftMonthStart(for: $0) }
            if endsAfter != normalized { endsAfter = normalized }
        }
    }
    var plan: MonthPlan?

    init(name: String,
         amount: Decimal,
         cadence: IncomeCadence = .fixed,
         affirmedAt: Date? = nil,
         startsOn: Date? = nil,
         endsAfter: Date? = nil) {
        self.name = name
        self.amount = amount
        self.cadence = cadence
        self.affirmedAt = affirmedAt
        self.startsOn = startsOn.map { Calendar.current.leftMonthStart(for: $0) }
        self.endsAfter = endsAfter.map { Calendar.current.leftMonthStart(for: $0) }
    }

    var effectiveCadence: IncomeCadence {
        cadence ?? .fixed
    }

    var isUnconfirmed: Bool {
        effectiveCadence == .variable && affirmedAt == nil && amount > 0
    }

    @discardableResult
    func affirm(amount newValue: Decimal? = nil, on date: Date = .now) -> Bool {
        let changed = newValue.map { max(0, $0) != amount } ?? false
        if let newValue {
            amount = max(0, newValue)
        }
        affirmedAt = date
        return changed
    }
}

// MARK: - Savings
// A flat amount is right for "I owe my Roth $583 a month". A percentage is
// right for variable income — it scales with the month instead of eating the
// whole daily budget in a lean one.

enum SavingsTarget: Equatable {
    case amount(Decimal)
    case percentOfIncome(Decimal)
}

@Model
final class SavingsGoal {
    static let maxPercent: Decimal = 100

    var name: String

    // The flat dollar goal. Like MonthPlan's legacy pair, this preserves the
    // last flat value while percent is non-nil so mode switches are reversible.
    var amount: Decimal
    var percent: Decimal?
    var plan: MonthPlan?

    init(name: String, amount: Decimal, percent: Decimal? = nil) {
        self.name = name
        self.amount = max(0, amount)
        self.percent = percent.map { min(max(0, $0), Self.maxPercent) }
    }

    var target: SavingsTarget {
        get {
            if let percent {
                .percentOfIncome(percent)
            } else {
                .amount(amount)
            }
        }
        set {
            switch newValue {
            case .amount(let value):
                amount = max(0, value)
                percent = nil
            case .percentOfIncome(let value):
                percent = min(max(0, value), Self.maxPercent)
            }
        }
    }

    var usesPercent: Bool {
        percent != nil
    }

    func resolvedAmount(income: Decimal) -> Decimal {
        switch target {
        case .amount(let value):
            return max(0, value)
        case .percentOfIncome(let percent):
            let cappedPercent = min(max(0, percent), Self.maxPercent)
            return (max(0, income) * cappedPercent / 100).roundedToCents()
        }
    }
}

// Allocations are history, not budget inputs. Confirmation stays separate
// because Left can suggest a transfer but cannot make one for the user.
@Model
final class SavingsAllocation {
    var name: String
    var amount: Decimal
    var date: Date
    var confirmedAt: Date?
    var plan: MonthPlan?

    init(name: String,
         amount: Decimal,
         date: Date = .now,
         confirmedAt: Date? = nil) {
        self.name = name
        self.amount = amount
        self.date = date
        self.confirmedAt = confirmedAt
    }
}

extension MonthPlan {
    static let maxSavingsPercent = SavingsGoal.maxPercent

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
        savingsAmount(for: incomeTotal)
    }

    // Used by DerivationLine while an income sheet is previewing a draft. All
    // percent goals resolve against that draft, not the persisted income.
    func savingsAmount(for income: Decimal) -> Decimal {
        if !savingsGoals.isEmpty {
            return savingsGoals.reduce(0) { partial, goal in
                partial + goal.resolvedAmount(income: income)
            }
        }

        return switch savingsTarget {
        case .amount(let value):
            max(0, value)
        case .percentOfIncome(let percent):
            (max(0, income) * percent / 100).roundedToCents()
        }
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
    var startsOn: Date? {
        didSet {
            let normalized = startsOn.map { Calendar.current.leftMonthStart(for: $0) }
            if startsOn != normalized { startsOn = normalized }
        }
    }
    var endsAfter: Date? {
        didSet {
            let normalized = endsAfter.map { Calendar.current.leftMonthStart(for: $0) }
            if endsAfter != normalized { endsAfter = normalized }
        }
    }
    var plan: MonthPlan?

    init(name: String,
         amount: Decimal,
         cadence: ExpenseCadence = .monthly,
         startsOn: Date? = nil,
         endsAfter: Date? = nil) {
        self.name = name
        self.amount = amount
        self.cadence = cadence
        self.startsOn = startsOn.map { Calendar.current.leftMonthStart(for: $0) }
        self.endsAfter = endsAfter.map { Calendar.current.leftMonthStart(for: $0) }
    }
}

protocol MonthWindowCovering {
    var startsOn: Date? { get set }
    var endsAfter: Date? { get set }
}

extension MonthWindowCovering {
    func covers(month: Date) -> Bool {
        let month = Calendar.current.leftMonthStart(for: month)
        return startsOn.map { $0 <= month } ?? true
            && endsAfter.map { month <= $0 } ?? true
    }
}

extension FixedExpense: MonthWindowCovering {}
extension IncomeSource: MonthWindowCovering {}

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
// No stored daily balances; cross-month carry is cached only so reconciliation
// has a migration-safe place to persist the latest derived boundary value.

extension MonthPlan {
    var activeIncomeSources: [IncomeSource] {
        incomeSources.filter { $0.covers(month: monthStart) }
    }

    var activeFixedExpenses: [FixedExpense] {
        fixedExpenses.filter { $0.covers(month: monthStart) }
    }

    // Existing stores remain readable before lazy migration materializes their
    // current month's legacy scalar as an IncomeSource.
    var incomeTotal: Decimal {
        guard !incomeSources.isEmpty else { return monthlyIncome }
        return activeIncomeSources.reduce(0) { $0 + $1.amount }
    }

    var fixedTotal: Decimal {
        activeFixedExpenses.reduce(0) { $0 + $1.monthlyAmount }
    }

    var carriedIn: Decimal {
        (carriedGross ?? 0) - carriedAllocated
    }

    // What's available for daily spending across the whole month.
    var monthlySpendable: Decimal {
        incomeTotal - fixedTotal - savingsAmount
    }

    // An untouched cushion must survive another boundary, while every transaction
    // still gets the chance to contribute, including one late on the final day.
    func endingSurplus(calendar: Calendar = .current) -> Decimal {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        return monthlySpendable
            - spent(asOf: nextMonth.addingTimeInterval(-1))
            + carriedIn
    }

    // Spending draws the allowance and cushion down together; allowance earned
    // later in the month lets the cushion recover without any warning state.
    // A deficit stays in the hero, while this floor simply leaves nothing to move.
    func cushion(on date: Date = .now, calendar: Calendar = .current) -> Decimal {
        max(0, min(carriedIn, remainingToday(on: date, calendar: calendar)))
    }

    // The transfer sheet's safety cap intentionally has its own semantic entry
    // point so its contract cannot drift with how the cushion is presented.
    func allocatableSurplus(on date: Date = .now) -> Decimal {
        cushion(on: date)
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

    // Carry raises the hero without changing the plan-supported rate. Allocating
    // a dollar therefore removes exactly a dollar here, with no retroactive rate
    // or calendar-tint changes.
    func remainingToday(on date: Date = .now, calendar: Calendar = .current) -> Decimal {
        let day = calendar.component(.day, from: date)   // 1-based
        let earned = dailyRate * Decimal(day)
        return earned - spent(asOf: date) + carriedIn
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
