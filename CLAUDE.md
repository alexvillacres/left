# Left — a minimal daily budget tracker

## What this is

A native iOS app with one job: show how much you can spend today.
The user sets monthly income, fixed expenses, and a savings goal once.
The app computes a daily allowance and tracks spending against it.
No accounts, no bank connections, no backend. All data on-device via SwiftData.

Core formula:
  monthlySpendable = income − fixedExpenses − savingsGoal
  dailyRate        = monthlySpendable / daysInMonth
  remainingToday   = dailyRate × dayOfMonth − totalSpentThisMonth

Rollover is DERIVED, never stored. Underspending yesterday automatically
increases today's number; overspending borrows from tomorrow. Transactions
are the only source of truth.

## Stack

- Swift 5.10+, SwiftUI, SwiftData. iOS 17 minimum.
- No third-party dependencies. None.
- Xcode project: Left (already scaffolded from the SwiftData template).
- The data model is already written: `BudgetModel.swift`. Use it as-is.
  Do not rename its types or invert its relationships.
- LeftTests / LeftUITests exist from the template. Leave them untouched
  in v1. Do not write tests unless asked.

## Files / structure

    Left/
      LeftApp.swift           — @main, ModelContainer, month-boundary check
      BudgetModel.swift       — provided; MonthPlan, FixedExpense, Transaction
      Screens/
        TodayView.swift       — home screen (the hero number)
        AddExpenseSheet.swift — numpad-first entry sheet
        MonthView.swift       — calendar grid of the month
        PlanView.swift        — income / expenses / savings setup
      Components/
        MoneyText.swift       — shared currency display helper
        NumpadView.swift      — custom keypad used by AddExpenseSheet

Keep it flat. Do not add view models, coordinators, routers, or protocols
for testability. SwiftUI views reading SwiftData queries directly is the
architecture.

## Screens

### 1. TodayView (root screen, 90% of usage)

- Top: current date (e.g. "Thu, Jul 2"), small, secondary color.
- Center, dominating the screen: "Left to spend today" caption, then the
  remaining amount HUGE (system rounded font, ~56pt, monospaced digits).
  Value from `plan.remainingToday()`.
- Color of the number by state:
    remaining > 25% of dailyRate  → green/teal
    0 < remaining ≤ 25%           → amber
    remaining ≤ 0                 → red, but calm. No warnings, no shame copy.
- Below the number: rollover chip if `plan.carryover()` ≠ 0:
    "+$27 rolled over" (positive, teal tint) or "−$12 from yesterday"
    (negative, subtle red tint). Hidden on day 1.
- Bottom third: today's transactions as a simple list (category SF Symbol,
  optional note, amount). Empty state: nothing. No illustration, no copy.
- Month progress footer: thin progress bar, "Day 14 of 31" left,
  net position right ("$41 ahead" / "$18 behind") from `plan.netPosition()`.
- Floating "+" button, bottom center, 56pt circle. Opens AddExpenseSheet.
- When the sheet dismisses after a save, the big number animates to its
  new value (count-down via `contentTransition(.numericText())` +
  spring) with a light haptic (`UIImpactFeedbackGenerator(style: .light)`).
  This animation is the soul of the app — do not skip it.

### 2. AddExpenseSheet (.presentationDetent .medium/.large)

- Amount display at top, large, starts at $0.00, cents-first entry
  (typing 6 5 0 → $6.50, like Venmo).
- One row of category chips from `Category.allCases`. Single select,
  default `.other`. Chips show SF Symbol + name.
- Custom NumpadView: 3×4 grid — digits plus backspace; no "." key needed
  with cents-first entry.
- Optional note field. Small, above the keypad, placeholder "Add note".
  Never required, never focused by default.
- Full-width "Log it" button pinned at bottom. Disabled at $0.00.
- Saving: insert Transaction into current MonthPlan, dismiss, haptic.
- The entire flow must be: open, type amount, tap Log it. Two seconds.

### 3. MonthView

- Calendar grid of the current month. Each day cell shows the day number
  and is tinted by outcome:
    under daily rate → teal tint
    within 10% over  → amber tint
    over             → red tint
    future days      → no tint
- Tap a day → simple list of that day's transactions (sheet or push).
- Header: total spent vs monthlySpendable, and projected savings from
  `plan.projectedSavings()` ("On pace to save $1,140").
- No charts in v1. The grid IS the chart.

### 4. PlanView

- Three sections: Monthly income (currency field), Fixed expenses
  (editable list: name + amount, swipe to delete, "Add expense" row),
  Savings goal (currency field).
- Below, ALWAYS visible, updating live as values change — the derivation:
    $6,200 − $2,840 − $1,000 = $1,360 ÷ 31 days = $43/day
  Render as a single line, dailyRate emphasized. This line is what makes
  the daily number trustworthy. Values from the current MonthPlan.
- Edits apply to the CURRENT month's plan only (snapshot semantics are
  built into the model).

### Navigation

TabView with three tabs: Today (sun icon), Month (calendar),
Plan (slider.horizontal.3). Today is the default tab. AddExpenseSheet
is modal, not a tab. Once the TabView root exists, the template's
ContentView.swift is deleted — no vestigial wrapper views.

## App lifecycle

In LeftApp on launch and on `scenePhase == .active`:
1. Fetch MonthPlan for the current month (compare normalized monthStart).
2. If missing and a previous plan exists → `previous.nextMonth()`, insert.
3. If NO plan exists at all → first launch → present PlanView as a
   full-screen onboarding (same view, "Get started" framing) before Today.

## Design rules

- Light + dark mode from day one. Use semantic system colors everywhere;
  the only custom colors are the three state tints (teal #1D9E75-ish,
  amber, red) defined once in an extension: Color.budgetPositive,
  .budgetWarning, .budgetNegative.
- SF Rounded for all numbers (`.fontDesign(.rounded)`), monospaced digits
  for anything that animates (`.monospacedDigit()`).
- Currency formatting: `Decimal.formatted(.currency(code: "USD"))`
  everywhere via the shared MoneyText component. Never format manually.
- Spacing on an 8pt grid. Generous whitespace. If a screen feels empty,
  it is correct.
- No onboarding carousel, no settings screen, no app icon badge, no
  notifications in v1.
- Copy is calm and neutral. Never "You overspent!" — the red number
  says it already.

## Build order (one commit each; STOP after each step so the human can
build and run in Xcode before continuing)

0. Template cleanup: delete Item.swift. Update the ModelContainer in
   LeftApp.swift to register [MonthPlan.self, FixedExpense.self,
   Transaction.self] and remove all references to Item. Point the root
   at a placeholder TodayView for now. Verify BudgetModel.swift compiles
   as part of the Left target.
1. PlanView + first-launch onboarding. Verify a MonthPlan persists
   across relaunch.
2. TodayView real layout with computed values.
3. AddExpenseSheet + NumpadView. Wire save → number animation + haptic.
4. MonthView grid.
5. Month-boundary logic + polish pass (dark mode audit, dynamic type).
6. Delete ContentView.swift if any reference to it still remains.

Note: when creating new .swift files, they must belong to the Left
target. If the build fails with "cannot find type" on a file that
exists, target membership is the first thing to check.

## Definition of done for the MVP

Fresh install → enter plan → see daily number → log an expense in under
3 seconds → number animates down → force-quit and relaunch → everything
persists. That's it. Resist adding anything else.
