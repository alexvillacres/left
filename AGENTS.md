# Left — repository guidance

## Product and documentation

Left is a native, manual daily budget tracker. No accounts, bank connections,
backend, analytics, or third-party dependencies. Data is stored on-device with
SwiftData. Read [PRODUCT.md](PRODUCT.md) for current behavior, vocabulary, and
open product questions; [DECISIONS.md](DECISIONS.md) records rationale and
superseded decisions. [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md) tracks
release readiness, not the feature roadmap.

User instructions take precedence over this guidance. Do not create markdown
files unless requested. `CLAUDE.md` is a symlink to this file; preserve it.

## Architecture

- SwiftUI and SwiftData; app deployment target iOS 17, iPhone, portrait.
- Keep views and helpers simple. Views read SwiftData queries directly. Do not
  add view models, coordinators, routers, or protocols for testability.
- Preserve existing `@Model` type names and relationship directions. Model
  changes require explicit consideration of existing stores and JSON backups.
- Leave the template LeftTests and LeftUITests untouched. Do not write tests
  unless asked.
- Xcode uses `fileSystemSynchronizedGroups`: new Swift files are discovered
  automatically. Do not edit the project file for target membership. Use
  `git mv` for renames of tracked files.

## Component organization

- `Components/UI/`: shared visual primitives and controls.
- `Components/Navigation/`: shared period controls and app navigation.
- `Components/Layout/`: shared screen structure and header chrome.
- `Components/Spending/`: spending-specific components shared across screens.
- `Screens/Today/`, `Screens/Activity/`, and `Screens/Plan/`: each screen and its specific sections.
  Other screens can adopt their own folders when they are next worked on.
- Keep small private helpers beside their owner. Extract substantial sections
  when it improves discoverability; move them into shared components when reused.
- A container owns consistent layout or behavior, not the declarations of every
  control placed inside it. Independent shared components use clearly named files.
- Remaining files directly in `Components/` have not yet been reorganized.

The shared `ScreenHeader` design uses `leftBackground`, standard header spacing,
and a 1-point `leftDivider` bottom border. Reuse this container for main-screen
headers; period controls remain independent components. All main screens use centered `PeriodNavigationRow` controls and
`ScreenHeadlineSlot` for matching headline height, with 44-point Medium amounts,
smaller tertiary state labels, and a reserved supporting line. Plan’s three flat
summary rows use neutral circular icons and unsigned whole-dollar totals. Settings is available in Plan’s month menu.
Design dimensions map to
SwiftUI points; reserve `1 / displayScale` for deliberate physical-pixel hairlines.

## Current file map

| File | Responsibility |
|---|---|
| `Left/LeftApp.swift` | Store loading/recovery, root navigation, onboarding, month creation and carry reconciliation |
| `Left/BudgetModel.swift` | Monthly plans, income sources, savings goals/allocations, recurring expenses, spending and budget math |
| `Left/Screens/Today/TodayView.swift` | Daily balance, day navigation, spending, and screen composition |
| `Left/Screens/Today/TodayBalanceBreakdown.swift` | Explanation opened by tapping the balance |
| `Left/Screens/Activity/ActivityView.swift` | Monthly browsing, spending grouping, and editing presentation |
| `Left/Screens/Activity/ActivityHeader.swift` | Month picker and total within shared header chrome |
| `Left/Screens/Activity/ActivityHistoryList.swift` | Grouped day headers, spending rows, and deletion |
| `Left/Screens/Plan/PlanView.swift` | Monthly plan composition, historical review, setup steps and plan editors |
| `Left/Screens/Plan/PlanHeader.swift` | Month navigation, spendable headline, and Settings access |
| `Left/Screens/Plan/PlanSummaryRow.swift` | Income, recurring-expense, and savings summary rows |
| `Left/Screens/IncomeSheet.swift` | Monthly source amount and whether it repeats |
| `Left/Screens/AddSpendingView.swift` | Full-screen cents-first spending entry |
| `Left/Screens/WeeklyReportView.swift` | Weekly report ticket, tiers, and tear-off dismissal |
| `Left/Screens/OnboardingView.swift` | Introduction leading into monthly setup |
| `Left/Screens/SettingsView.swift` | Privacy/support links and debug-only backup access |
| `Left/DataTransfer.swift` | Debug-only JSON export/import and validation |
| `Left/Components/` | Shared controls, derivation, keypad, navigation and sheet chrome |
| `Left/Palette.swift`, `BudgetFont.swift`, `AppSpacing.swift` | Shared visual conventions |
| `Left/Components/UI/MoneyText.swift` | Shared currency display |
| `Left/Screens/Today/TodayEmptyState.swift` | Empty spending illustration and copy |

## Budget invariants

Use model calculations, not parallel formulas inside views:

```text
monthlySpendable = incomeTotal − fixedTotal − savingsAmount
dailyRate        = monthlySpendable / daysInMonth
remainingToday   = dailyRate × earnedDays − spentAsOf + carriedIn
carriedIn        = carriedGross − carriedAllocated
```

- `earnedDays` starts at the plan's first active day. Starting mid-month does
  not grant earlier days' allowances or divide the budget over fewer days.
- Daily balances and within-month rollover are derived. Transactions record
  spending; plan data supplies the allowance. Do not store daily balances.
- Cross-month carry has existing persisted fields: `carriedGross` is a
  reconciled cache; preserve user allocation state when reconciling it.
- Read `incomeTotal`, `fixedTotal`, and `savingsAmount` for resolved totals.
  Legacy scalar fields remain for compatibility; do not casually delete them.
- Plans are monthly snapshots. Current Plan is editable; past Plan screens are
  read-only. Spending history remains editable and changes derived balances.
- Cloning carries repeating income amounts forward. Sources requiring a new
  monthly amount become placeholders; incomplete income gates the allowance.
  An explicitly entered zero is different from an unfilled placeholder.
- Catch-up is spending, counted once on its end date. Its range is metadata,
  not an instruction to distribute or duplicate its amount across days.
  Prompt acknowledgement is not a transaction or proof of a bank balance.

## UI conventions

- Organize around Today, Activity, and Plan. Settings is a utility destination.
  The bottom tab bar is navigation only. The + button lives on Today and only
  logs spending; other screens add through their own rows.
- Use DM Sans through existing font helpers, semantic palette colors, shared
  spacing, and monospaced digits for changing amounts. Do not restore the old
  teal hero, calendar, or spending meter.
- Color has personality but a fixed job. Ink is the action color. Orange means
  recurring expenses, periwinkle means savings, and sage means spendable; use
  them only for those parts of the plan, mainly as fills and marks. Income is
  the neutral whole they divide. Other brand hues are expressive only.
  Celebration surfaces that do not explain the plan, such as the weekly
  report, may use any brand hue expressively; keep them restrained. Warning
  and negative alone signal state. Screens use a neutral grey ground, never a
  tinted one; see DECISIONS 027, 029, and 036.
- Use shared currency helpers and Foundation USD currency formatting. Never
  manually assemble currency strings.
- Spending uses cents-first `NumpadView`. Plan
  amounts are whole-dollar and use the system decimal keyboard through
  `MoneyField` on a short sheet. This covers every Plan editor and the onboarding
  setup steps. Onboarding and the recurring-expense sheet still use `NumpadView`
  until they are migrated. Never make a plan amount cents-first; see DECISIONS
  014 and 033.
- Preserve numeric transitions and light save haptics; honor Reduce Motion.
- Support light/dark appearance, Dynamic Type, VoiceOver, and 44-point touch
  targets. New sheets own an opaque background using existing sheet chrome.
- Copy is clear and specific. Explain the balance as based on the plan and
  logged spending; it is not an observed bank balance.

## Working and verifying

Inspect the working tree first and preserve unrelated edits. Keep changes
coherent; stage named files when committing. Do not invent authorship trailers.
For code changes, build the app and manually verify the affected flow. For UI
changes, check light/dark mode and larger text. Do not claim checks that were
not run. Documentation-only changes need link and consistency checks, not an
app rebuild. The original scaffold build sequence is complete and no longer
controls work.

## Design iteration in Paper

Never overwrite or replace an existing Paper screen. Duplicate it, name the copy
with an iteration suffix (for example `Plan · v3 rows`), and edit the copy, so
every earlier version stays visible and changes can be compared. Do not rebuild a
body in place. When asked to discuss or give reasoning, discuss first and make
no canvas changes until asked.
