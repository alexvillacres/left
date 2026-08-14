# Naming

Two kinds of money leave your account in this app, and until now the UI called
both of them "expense." This is the split, and why it lands where it does.

## The rule

| Concept | User-facing | Code type |
|---|---|---|
| A thing you bought today — coffee, lunch, a cab | **spending** | `Transaction` |
| A cost that repeats — rent, insurance, Spotify | **recurring expense** | `FixedExpense` |

The word "expense," unqualified, now belongs to the recurring side. Do not use it
for daily entries.

## Why it needed fixing

The model layer already had this right: `Transaction` and `FixedExpense` are
distinct types and always have been. The UI layer collapsed them. Before this
change, every user-facing string used "expense" for both:

- "Add Expense" on Today logged a `Transaction`
- "Add expense" in Plan added a `FixedExpense`
- "Add fixed expense" in onboarding added a `FixedExpense` — same action as the
  line above, different label
- "New Expense" titled the `FixedExpense` form
- "Delete expense" deleted a `Transaction`

Worse, `Screens/AddExpenseSheet.swift` and `PlanView.addExpenseSheet` were two
different sheets with effectively the same name. That one is a trap for anyone
reading this codebase cold.

## Why these words

**"Spending" for the daily side.** The alternative was "transaction," which
matches the type name exactly and needs no translation between code and UI. It
was rejected: it is bank-statement vocabulary on the button pressed five times a
day, and this app's copy is meant to be calm and plain. The high-frequency action
gets the warm word.

**"Recurring expense" for the fixed side.** This does something the old name
didn't — it frees up "fixed." `IncomeCadence.fixed` means *income that doesn't
vary*, while "fixed expenses" meant *costs that repeat*. Same adjective, two
unrelated senses, in one small app. "Recurring" says what is actually meant and
leaves "fixed" pointing at exactly one thing.

**"Recurring" over "bills."** "Bills" is shorter and warmer, but not everything
in that list is a bill — savings transfers and allowances belong there too, and
calling them bills would be wrong rather than merely dry.

## The mass-noun wrinkle

"Spending" has no singular. There is no such thing as "a spending," so it works
for aggregates and headings but not for individual items or destructive actions.
Since "expense" is now spoken for, the daily side simply avoids naming the
individual item:

| Context | String |
|---|---|
| Add action, Today | *(no label — see below)* |
| Sheet confirm | "Log it" |
| Sheet destructive | "Delete" — the noun is dropped, not replaced |

If a future screen needs to name one daily item in the singular, solve it then.
Do not reach for "expense."

## What changed

**Renamed** (via `git mv`, history preserved):
- `Left/Screens/AddExpenseSheet.swift` → `AddSpendingSheet.swift`
- `struct AddExpenseSheet` → `AddSpendingSheet`
- `PlanView.addExpenseSheet` → `recurringExpenseSheet`
- `TodayView.activeExpenseSheet` / `ActiveExpenseSheet` → `activeSpendingSheet` /
  `ActiveSpendingSheet`

**Strings:**
- `TodayView` — "Add Expense" button replaced by a bare "+"; accessibility label
  "Add spending"
- `AddSpendingSheet` — "Delete expense" → "Delete"
- `PlanView` — "Fixed expenses" → "Recurring expenses"; "Add expense" and "Add
  fixed expense" both → "Add recurring expense"; "New Expense" → "New recurring
  expense"; onboarding eyebrow → "RECURRING EXPENSES"; empty state → "No
  recurring expenses added"; zero-budget warning now says "adjust your recurring
  expenses"; amount field accessibility label → "Recurring expense amount"
- `DerivationBar` — accessibility label "minus fixed expenses" → "minus
  recurring expenses"
- `IncomeSheet` — comment reference to the old sheet name

No `project.pbxproj` edit was needed: the project uses Xcode 16
`fileSystemSynchronizedGroups`, so the file rename is picked up from disk.

## What deliberately did not change

**The `@Model` type names.** `Transaction` and `FixedExpense` stay. Renaming a
SwiftData model class means a store migration, and neither name is ever shown to
a user. The translation cost between code and UI is one line of this document;
the migration cost is real.

**`PlanView`'s state vars** — `isAddingExpense`, `newExpenseName`,
`newExpenseAmount`, `newExpenseCadence`. They live entirely inside PlanView's
recurring-expense context, where "expense" is unambiguous, and renaming them
would widen the diff without removing any confusion.

## The "+" button

Today's add button lost its label at the same time. Logging spending is the only
action that screen offers, so a labelled button was spending a full-width bar to
say something the context already said. It is now a 56pt circle anchored to the
bottom-right of its container, where a thumb already rests.

The glyph uses a fixed `.system(size: 24, weight: .semibold)` rather than the
app's scaling `.dmSans`. It is an icon inside a fixed-size circle: letting it
grow with Dynamic Type would clip it. This is the one place in the app where not
scaling with text is correct.

## Still open

The income model is heading toward multiple named sources with start and end
dates, parallel to `FixedExpense`. When that lands it inherits this vocabulary —
"Income" and "Recurring expenses" read as counterparts, and the per-source
lifespan question (do dates own an item across months, or only within one?)
should be settled for both at once, since `MonthPlan.nextMonth()` currently
clones every expense forward with no notion of an end date.
