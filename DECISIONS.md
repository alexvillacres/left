# Decisions

Why this app is the way it is. One entry per decision that cost real thought —
especially the ones where the obvious choice was rejected.

## What belongs here

Add an entry when a decision meets **any** of these:

- An obvious alternative was rejected for a non-obvious reason.
- It constrains future work ("do not add X", "never reach for Y").
- Someone reading the code cold would assume it was an accident.
- It was reversed. Reversals get their own entry; the old one is marked
  superseded, never deleted.

Do **not** add an entry for something a code comment already carries well. The
rule of thumb: if the rationale is only relevant when you are looking at that
exact file, it is a comment. If it would change what you build in a *different*
file, it belongs here.

Entries identify the relevant implementation. Superseded entries may reference
files that no longer exist; those paths are historical, not build instructions.
Current behavior and vocabulary live in [PRODUCT.md](PRODUCT.md).

## Template

```markdown
### NNN. Short imperative title
**Date:** YYYY-MM-DD · **Status:** Active | Amended by NNN | Superseded by NNN | Deferred
**Where:** `Path/To/File.swift`, `Other.swift`

The decision, in one or two sentences.

**Why:** What made this the right call. Name the alternative that was rejected
and the specific reason it lost.

**Constrains:** What this forbids or forces later. Omit if nothing.
```

Numbers are permanent and never reused. Dates are the date of the decision, not
the date it was written down. Entries below marked *(reconstructed)* were
recovered from code comments and commit history after the fact — their dates are
the commit that introduced them and may lag the actual decision.

---

## Data model

### 001. Rollover is derived, never stored
**Date:** 2026-07-02 · **Status:** Amended by 002
**Where:** `Left/BudgetModel.swift`

Transactions are the only source of truth. Underspending yesterday raises
today's number; overspending borrows from tomorrow. Nothing writes a daily
balance.

**Why:** Stored balances go stale the moment history is edited. Deriving means a
correction to a transaction from three days ago flows forward automatically,
with no reconciliation pass and no way for the display to disagree with the
data.

**Constrains:** No stored daily balances, ever. If a number on screen cannot be
computed from plan + transactions, question the number, not the rule.

### 002. Cross-month carry is cached, but only as a migration-safe boundary value
**Date:** 2026-08-05 · **Status:** Amended by 023 and 025 *(reconstructed)*
**Where:** `Left/BudgetModel.swift` — `carriedGross`, `carriedAllocated`,
`carryAnnouncedAt`

001 holds *within* a month. Across a month boundary, three fields persist:
`carriedGross` caches the prior plan's final position and is recomputed on
launch; `carriedAllocated` is the only stored money decision in the app; and
`carryAnnouncedAt` records that the decision was offered.

**Why:** `carriedGross` is a cache — recomputing it on launch keeps 001 true,
since later edits to history still flow forward. `carriedAllocated` genuinely
cannot be derived: only the user can decide that part of an inherited surplus
belongs in savings, so it survives reconciliation by design. `carryAnnouncedAt`
exists so the prompt is offered once rather than every launch.

**Original constraint (replaced by 023 and 025):** These three were described
as the only stored money state. Current persistence rules are in those amendments.

### 003. Snapshot the plan per month
**Date:** 2026-07-02 · **Status:** Amended by 022
**Where:** `Left/BudgetModel.swift` — `MonthPlan`, `nextMonth()`

One `MonthPlan` record per calendar month, holding its own copy of income,
expenses, and savings target. Edits apply to the current month only.

**Why:** Past months stay historically accurate when income changes. A single
mutable plan would silently rewrite every previous month's daily rate the moment
you got a raise.

**Current constraint (022):** `clone(for:)` is the shared clone path, with
`nextMonth()` delegating to it. Source amount repetition replaces the original
per-source affirmation rule; past Plan screens remain read-only.

### 004. Savings target stores both shapes at once
**Date:** 2026-07-15 · **Status:** Active
**Where:** `Left/BudgetModel.swift` — `savingsGoal`, `savingsPercent`,
`savingsAmount`

A target is a flat amount *or* a percent of income. Both fields persist: the
flat value is retained while `savingsPercent` is non-nil.

**Why:** A flat amount is right for "I owe my Roth $583 a month." A percent is
right for variable income — it scales with the month instead of eating the whole
daily budget in a lean one. Keeping both means toggling the segmented control is
reversible; discarding the unused half would silently destroy what you typed.
`savingsPercent` is optional so existing plans migrate straight to flat-amount.

**Constrains:** Budget math reads `plan.savingsAmount`. Nothing else may read
`savingsGoal` directly.

### 005. Keep legacy scalar fields rather than migrate the store
**Date:** 2026-08-05 · **Status:** Amended by 025 *(reconstructed)*
**Where:** `Left/BudgetModel.swift` — `monthlyIncome`, plan-level `incomeCadence`,
plan-level affirmation timestamp

Income became a collection of `IncomeSource`s, and savings became multiple
goals. The old plan-level scalars stay on the model, read only by plans written
before the change, and migrate lazily.

**Why:** A SwiftData schema migration on a shipping app is a real risk for a
cosmetic gain. Lazy migration means an old store opens and works, and the
current month materializes its legacy scalar as an `IncomeSource` when touched.

**Current constraint (025):** Use resolved totals and sources in new features.
Legacy fields remain for compatibility; the original proposed deletion after
the first App Store release is not an approved migration deadline.

### 006. Do not rename the `@Model` types
**Date:** 2026-07-31 · **Status:** Active
**Where:** `Left/BudgetModel.swift`, [PRODUCT.md](PRODUCT.md#vocabulary)

`Transaction` and `FixedExpense` keep their names even though the UI now says
"spending" and "recurring expense."

**Why:** Renaming a SwiftData model class means a store migration. Neither name
is ever shown to a user, so the translation cost is one row of a table in
[PRODUCT.md](PRODUCT.md#vocabulary); the migration cost is real.

---

## Vocabulary

### 007. "Spending" for daily, "recurring expense" for fixed
**Date:** 2026-07-31 · **Status:** Amended by 026
**Where:** [PRODUCT.md](PRODUCT.md#vocabulary), all user-facing strings

The unqualified word "expense" belongs to the recurring side only.

**Why:** "Transaction" matches the type name but is bank-statement vocabulary on
the button pressed five times a day. "Recurring" over "fixed" frees "fixed" to
mean exactly one thing (`IncomeCadence.fixed` — income that doesn't vary).
"Recurring" over "bills" because savings transfers in that list are not bills.

**Constrains:** "Spending" is a mass noun with no singular, so the daily side
avoids naming an individual item. Destructive action is "Delete", not "Delete
expense". If a screen ever needs the singular, solve it then — do not reach for
"expense". See PRODUCT.md for current vocabulary and model-name mappings.

---

## Visual system

### 008. The palette exposes intent, never hue
**Date:** 2026-08-04 · **Status:** Amended by 021
**Where:** `Left/Palette.swift`

Raw neutral and fern ramps are `private`. Only semantic, appearance-aware colors
are public. A view asks for `leftPositiveFill`; it cannot ask for a specific
gray.

**Why:** When views reached raw hex values directly, status chips and the today
meter rendered light-mode colors on a dark background. Naming intent means light
and dark stay in step from one place, and a view physically cannot pin itself to
a fixed hue.

**Constrains:** Meter fills bake in their own blending. Callers must **not**
apply `.opacity()` on top — a translucent fill over a dark track reads as mud.

### 009. Positive is neutral; only warning and negative carry color
**Date:** 2026-08-04 · **Status:** Superseded by 027
**Where:** `Left/Palette.swift`

**Why:** If every state is colored, no state is legible at a glance. Being fine
is the common case and deserves no visual weight; the two states worth noticing
keep their semantic color.

### 010. Ship a custom floating tab bar instead of `TabView`
**Date:** 2026-08-04 · **Status:** Superseded by 028
**Where:** `Left/Components/FloatingTabBar.swift`, `Left/LeftApp.swift`

A content-width capsule floating clear of the screen edges, not a bar pinned to
the bottom.

**Why:** Two independent reasons. Mechanically, `TabView` does not propagate a
bottom `safeAreaInset` into its children, so the capsule drew on top of list
content. Visually, separation comes from a shadow rather than a material —
against a white screen a translucent bar has nothing behind it to reveal and
collapses into gray. Shadows vanish against black, so the capsule handles dark
mode on its own terms.

**Constrains:** The bar publishes its height so callers reserve a matching
bottom inset. Any new scrolling screen must consume it.

### 011. `ViewThatFits` over `minimumScaleFactor` for the hero number
**Date:** 2026-07-15 · **Status:** Active
**Where:** `Left/MoneyText.swift`

The hero amount steps down through fixed sizes.

**Why:** Combining tight tracking with `minimumScaleFactor` makes SwiftUI clip
the outer glyphs. Discrete steps also keep the digits on a known size, which
matters for the count-down animation.

### 012. The "+" glyph is the one thing that does not scale with Dynamic Type
**Date:** 2026-07-31 · **Status:** Amended by 026
**Where:** `Left/Screens/TodayView.swift`, [PRODUCT.md](PRODUCT.md#vocabulary)

Fixed `.system(size: 24, weight: .semibold)` rather than the app's scaling
`.dmSans`.

**Why:** It is an icon inside a fixed-size 56pt circle. Growing it clips it.
This is the only correct place in the app for a non-scaling size — everywhere
else, a fixed font size is a bug.

### 013. The today meter replaced the week strip
**Date:** 2026-08-03 · **Status:** Superseded by 021 *(reconstructed)*
**Where:** `Left/Components/TodayMeter.swift`

**Why:** The strip showed seven days at once on a screen whose entire job is
today. The meter answers the only question being asked. Its fill moves through
the semantic palette as the budget is used; the final red overlay stays
partially transparent over warning amber, producing an orange-red nub just
before depletion rather than a hard color flip.

---

## Interaction

### 014. Cents-first entry belongs to `NumpadView` and nowhere else
**Date:** 2026-07-15 · **Status:** Amended by 033
**Where:** `Left/Components/NumpadView.swift`, `Left/Components/MoneyField.swift`

`NumpadView` is for logging spending — the thing done five times a day, where
typing `650` means $6.50. `MoneyField` uses the **system** decimal pad, where
`650` means 650.

**Why:** Cents-first buys real speed on the high-frequency action. On plan
values set a few times a year inside a scrolling form, selection, paste, and
free dismissal matter more, and a surprising interpretation of a typed number is
a bug waiting to happen.

**Constrains:** Do not "unify" these two. The split is the decision.

**Amended 2026-09-21:** Onboarding and the recurring-expense sheet use
`NumpadView` for plan amounts, but in whole-dollar mode: typing `340` means $340, and passing
`onDecimal` turns the blank key into "." for cents. The sheet keeps its fields in
one compact card, and the system keyboard covered the card it was editing. The
split that still stands is about meaning, not the widget: only spending is
cents-first. *(This amendment is superseded by 033: plan amounts move back to
the system keyboard. The cents-first rule above still stands.)*

### 015. Spending entry is full-screen, and the note is a pushed screen
**Date:** 2026-08-04 · **Status:** Active
**Where:** `Left/Screens/AddSpendingView.swift`

`AddSpendingSheet` became `AddSpendingView`, presented full-screen with no
detents. The optional note moved to its own pushed screen.

**Why:** The two detents existed solely so the sheet could shrink for the note
field's keyboard — and the numpad needs no keyboard at all. Moving the note to a
screen where the keyboard has room removed both detents, their computed heights,
the focus-driven resize, and a double keyboard-inset workaround.

### 031. Swipe deletion is immediate and offers Undo
**Date:** 2026-10-15 · **Status:** Active
**Where:** `Left/Components/UndoBar.swift`, `Left/LeftApp.swift`

Swiping a spending entry away on Today or Activity deletes it at once and
shows an ink bar naming the amount and entry ("Deleted $18.50 · Lunch with
Sam") with Undo for five seconds, ten with VoiceOver. Undo re-creates the
entry with its original ID, date, and catch-up range. On Today the bar sits
beside the + button on the same line. AppRoot owns the bar so it survives a
tab switch.

**Why:** Deletion had no undo, and a full swipe made a mistaken delete one
gesture away. A confirmation dialog would add friction to every intended
delete, and turning off full swipe still could not reverse an intended one. Most
apps reviewed delete at once and offer Undo in a short bar. Naming the amount
matters here because deleting spending changes the balance.

**Constrains:** Swipe deletes go through the `deleteSpending` environment
action, not `modelContext.delete`. Delete inside the edit screen is a
deliberate tap and does not show the bar.

Today has no horizontal swipe between days. The previous-day and next-day
arrows, the date menu, and the VoiceOver actions change the day. The day swipe
covered the whole screen, list included, so swiping a row left also opened the
next day. It was a hidden duplicate of the arrows, so it was removed rather
than limited to the header. Do not add a horizontal screen gesture to Today
while rows swipe to delete.

---

## App lifecycle

### 016. A store failure gets a screen, not a crash and not a fallback
**Date:** 2026-08-11 · **Status:** Active
**Where:** `Left/LeftApp.swift`, `Left/Screens/StoreRecoveryView.swift`

Opening the `ModelContainer` is the one operation that can fail before the app
exists. Failure surfaces as `StoreRecoveryView`, which explains itself and
offers a reset.

**Why:** `fatalError` would brick every future launch with no way out but
deleting the app — and the realistic cause is an unresolvable migration, which
does not fix itself. An in-memory fallback would be worse: the app looks normal
while quietly discarding everything typed into it. The reset deletes the store
*and* its write-ahead log sidecars, since leaving those behind can resurrect the
same corrupt state.

**Constrains:** The underlying error string stays visible on screen rather than
logged — on TestFlight it is the only detail a tester can hand back.

### 017. Settings exists for App Review, not for preferences
**Date:** 2026-08-11 · **Status:** Amended by 024
**Where:** `Left/Screens/SettingsView.swift`

Nothing on this screen is configurable. It carries the Privacy and Support links
and one plain sentence that data never leaves the device.

**Why:** The App Store requires those links reachable in-app, and a dead link is
a rejection. The on-device claim is worth saying once where it is actually
reassuring.

**Constrains:** `AGENTS.md` says "no settings screen." This is the exception and
must stay one. Resist letting it grow into a preferences panel.

---

## Tooling

### 018. File changes need no `project.pbxproj` edit
**Date:** 2026-07-31 · **Status:** Active
**Where:** `Left.xcodeproj/project.pbxproj`

The project uses Xcode 16 `fileSystemSynchronizedGroups`. New and renamed files
are picked up from disk.

**Why:** Recorded because `AGENTS.md` used to advise checking target membership
when a build fails with "cannot find type." That advice predated the Xcode 16
project format and sent you looking in the wrong place; the real cause is always
a compile error elsewhere. Corrected in the same commit as this entry.

**Constrains:** Renames should use `git mv` so history is preserved.

### 019. `AGENTS.md` is the brief; `CLAUDE.md` is a symlink to it
**Date:** 2026-08-13 · **Status:** Active
**Where:** `AGENTS.md`, `CLAUDE.md`

The two files were byte-identical copies. `CLAUDE.md` is now a symlink.

**Why:** Two hand-maintained copies of the same rules drift, and the drift is
silent — you would not notice until an agent followed the stale one. A symlink
makes divergence impossible while keeping both filenames working, so any tool
looking for either name still finds the brief.

**Constrains:** Edit `AGENTS.md`. Never replace the symlink with a real file.

### 020. Action sheets own an opaque system background
**Date:** 2026-08-14 · **Status:** Amended by 027
**Where:** `Left/Components/DerivationBar.swift`, Plan editor sheets

Action sheets use the app's custom header and paint
`Color(uiColor: .systemBackground)` edge to edge, including an explicit solid
presentation background.

**Why:** Allowing the system presentation or navigation surface to show through
introduces Apple's glass treatment, which does not match the app's quiet,
solid-surface sheet language.

**Constrains:** New action sheets must provide their own opaque background and
must not rely on built-in glass navigation chrome for their primary surface.


## Current product direction

### 021. Organize around Today, Activity, and Plan
**Date:** 2026-09-19 · **Status:** Active
**Where:** `Left/Screens/TodayView.swift`, `Left/Screens/ActivityView.swift`,
`Left/Screens/PlanView.swift`, `Left/Screens/TodayBalanceSheet.swift`

Today answers what is available, Activity records what happened, and Plan
explains the allowance's basis. The month calendar and Today meter were removed
on September 16; monthly plan review and the balance explanation followed.

**Why:** The calendar and meter did not earn their space. A readable spending
history and an explanation on demand support the user's next action without
adding persistent visual weight to Today.

**Constrains:** Do not restore the meter or calendar from the original brief.
008's semantic palette principle remains; its meter-specific constraints are
historical. Today stays focused on the amount, while a tap reveals allowance,
carry, logged spending, and the resulting balance.

### 022. Ask whether a monthly income amount repeats
**Date:** 2026-09-19 · **Status:** Amended by 034
**Where:** `Left/BudgetModel.swift` — `clone(for:)`, `needsMonthlyAmount`,
`Left/Screens/IncomeSheet.swift`, `Left/Screens/PlanView.swift`

Each source either repeats its amount next month or requires a fresh monthly
amount. Retire the vague “Still expecting?” affirmation flow. Current-month
Plan is editable and previous monthly plans are available read-only.

**Why:** Confirming an expectation conflates the amount, payment arrival, and
continued existence of a source. A monthly budgeting amount has a clear role
without requiring a separate freelancer product or a receipt ledger.

**Constrains:** Repeating amounts clone forward; non-repeating sources clone as
placeholders and gate the allowance until filled. Preserve stored cadence raw
values and compatibility fields. An explicitly entered zero is valid and differs
from a missing amount. Monthly snapshots do not imply an intra-month edit log.
This replaces 003's per-source affirmation rationale.

### 023. Catch up with one additional spending total
**Date:** 2026-09-19 · **Status:** Active
**Where:** `Left/Screens/TodayView.swift`, `Left/Components/CatchUpCard.swift`, `Left/Screens/CatchUpView.swift`,
`Left/Screens/ActivityView.swift`, `Left/BudgetModel.swift`, `Left/DataTransfer.swift`

Offer catch-up from Today, with a prompt after three uncovered days. If the
user makes no entry or acknowledgement, show it again after three more days,
not on each visit to Today. Store one editable transaction with a covered date
range and count it on the range's last
day. It represents spending not already logged.

**Why:** Manual tracking needs a forgiving return path after missed entries.
Requiring every purchase to be reconstructed makes resuming harder.

**Constrains:** Never spread or duplicate the amount across the covered dates.
“Nothing spent” records acknowledgement, not spending. The current close action
also acknowledges the period; different snooze behavior remains an open question.
`catchUpAcknowledgedThrough` records acknowledgement;
`catchUpPromptShownAt` records reminder cadence. Neither is a daily balance.
Update backup handling when changing catch-up data.

### 024. Keep JSON backup a debug utility
**Date:** 2026-08-24 · **Status:** Active *(reconstructed)*
**Where:** `Left/DataTransfer.swift`, `Left/Screens/DataBackupView.swift`,
`Left/Screens/SettingsView.swift`

JSON export/import is compiled only in Debug and reached through Settings.
Settings otherwise remains a small privacy/support utility destination.

**Why:** Development data portability is useful without committing to a public
transaction-import experience. It does not settle CSV or natural-language import.

**Constrains:** Do not advertise backup as a release feature. 017's absolute
claim that nothing leaves the device must account for deliberate debug exports;
its old exception to “no settings” is replaced by current AGENTS.md guidance.

### 025. Accrue from the first active day and preserve compatibility
**Date:** 2026-09-19 · **Status:** Active *(documented from current implementation)*
**Where:** `Left/BudgetModel.swift` — `firstActiveDay`, `earnedDays`,
`plannedSpend`, `endingSurplus`, `Left/LeftApp.swift` — carry reconciliation

A partial first month keeps the normal monthly daily rate and earns it only
from the first active day. Remaining money includes reconciled cross-month carry,
less existing user allocation state, and subtracts logged spending.

**Why:** Starting mid-month should not grant fictitious earlier allowances.
Later history edits should still flow through derived balances and carry.

**Constrains:** 002's original “only stored money state” wording is historical,
not a ban on the plan, transaction, allocation, and compatibility fields now in
the model. Do not persist daily balances. Do not delete legacy scalar fields on
an assumed release deadline from 005; assess store and backup compatibility
explicitly. Existing allocation data does not establish a current savings-transfer
UI or decide the open product question.

### 026. Keep current guidance separate from historical rationale
**Date:** 2026-09-19 · **Status:** Active
**Where:** `AGENTS.md`, `PRODUCT.md`, `DECISIONS.md`, `APP_STORE_CHECKLIST.md`

AGENTS holds implementation guidance, PRODUCT describes behavior and open
questions, DECISIONS preserves rationale, and the checklist tracks release
readiness. Remove GIT_WORKFLOW and fold useful NAMING vocabulary into PRODUCT.

**Why:** The original scaffold brief and dated task notes were contradicting the
app. A small set of documents with distinct jobs reduces that drift.

**Constrains:** Preserve decision numbers and mark reversals. The singular
“entry” is acceptable for spending, superseding 007's instruction to avoid a
noun. 012's historical fixed glyph dimensions are not a universal typography
exception: use current components, scalable text, and accessible touch targets.
Keep CLAUDE.md as a symlink to AGENTS.md.

### 027. Color carries plan meaning and brand personality
**Date:** 2026-09-19 · **Status:** Amended by 029
**Where:** `Left/Palette.swift`, onboarding, Plan, balance explanation

Left no longer aims for a calm, neutral interface. Ink (near-black, near-white
in dark mode) is the action color. Three brand hues name where monthly income
goes: orange is recurring expenses, periwinkle is savings, and sage is
spendable. Income is the neutral whole they divide, drawn as the track the
segments fill. Other brand hues, such as butter and tan, are expressive only:
onboarding grounds, illustration, and empty states. The fern ramp is retired.

**Why:** The brand is gaining personality through illustration and the
marketing site, and a neutral app would read as a different product. Tying hue
to a plan category makes the color useful: the allocation bar learned in
onboarding explains the plan wherever it reappears. A single brand accent was
rejected because one hue cannot show a three-way split. 009's neutral positive
was rejected because the product no longer treats visual weight as the thing to
minimize.

**Constrains:** A category hue means only its category; never use it
decoratively or for another concept. Category hues are fills and marks (bar
segments, focus rings, dots); amounts stay in ink, except that the spendable
amount may use the sage text shade. Text shades must meet 4.5:1. Buttons and
interactive tint use ink, never a brand hue. Warning and negative alone signal
state, and orange must never signal overspending. Pair color with a label so
meaning never depends on color alone. 008 still applies: views request named
roles, not hues. 020's opaque sheet rule stands, but screens and sheets now
paint `leftBackground` (and cards `leftSurface`) instead of the system
backgrounds so the tinted neutrals show; its "quiet" rationale no longer
describes the direction.

### 028. The tab bar navigates; + logs spending on Today
**Date:** 2026-09-22 · **Status:** Active
**Where:** `Left/Components/AppTabBar.swift`, `Left/Screens/TodayView.swift`,
`Left/LeftApp.swift`

The floating capsule became a full-width, opaque bar with a hairline top edge.
The selected tab is shown by icon color alone. The contextual add slot is gone:
Today owns a single ink + button that opens spending entry, and Activity and
the Plan editors add through their own rows.

**Why:** One + meant five different things, and the bar changed width as
screens installed and cleared actions. That made the capsule shift sideways,
and view lifecycle ordering sometimes left the button missing. Making + mean
only spending, on the screen where spending is logged, removed both problems.

**Constrains:** Do not reintroduce screen-installed actions into the tab bar.
New entries, including ones for past days, start from Today by navigating to
the day; Activity edits existing entries. It is still a custom bar rather than `TabView`, so a tab switch still
resets that screen's navigation path.

### 029. Celebration surfaces may use brand hues freely
**Date:** 2026-09-28 · **Status:** Active
**Where:** `Left/Screens/WeeklyReportView.swift`, `Left/Palette.swift`

027's category rule governs the plan and the math that explains it: wherever
orange, periwinkle, or sage appears beside plan amounts, it still means
recurring expenses, savings, or spendable. Surfaces that celebrate rather than
explain, starting with the weekly report, may use any brand hue, including
periwinkle, as an expressive ground. Restraint comes from composition instead
of a hue ban: one ground color and one illustration per surface, with ink
type.

**Why:** Left should feel expressive, and the weekly report tickets are where
personality pays off. Banning the category hues outside the plan would leave
only butter and tan for every expressive moment and make the brand read
smaller than it is. Keeping them out of celebration screens protected a
meaning those screens never carry, because a weekly report shows no plan
breakdown for a periwinkle ground to be confused with.

**Constrains:** A category hue must not appear as a fill or mark on a
celebration surface that also shows plan categories; if a surface explains the
plan, 027 applies in full. Text stays ink and meets 4.5:1 against the chosen
ground. Buttons still use ink. Warning and negative still alone signal state,
so an expressive ground must never be chosen to imply a good or bad week.

### 030. Each main tab opens on a light ground that stays light in dark mode
**Date:** 2026-10-01 · **Status:** Superseded by 036
**Where:** `Left/Components/ScreenHeader.swift`, `Left/Palette.swift`,
`Left/Screens/TodayView.swift`, `Left/Screens/ActivityView.swift`,
`Left/Screens/PlanView.swift`

Today, Activity, and Plan each open on a solid ground block holding the period
row and one headline number: butter for Today ("left"), tan for Activity
("spent"), and a pale sage for Plan ("to spend"). The screen's content sits on
a rounded sheet that rises over the bottom of the block and separates on a
hairline rather than a shadow. The tab bar names the screen, so the title row
is gone; Plan's Settings sits beside the headline. A header carries no
subtext in the normal state: Today's yesterday line and Plan's daily rate were
cut because the balance explanation and the allocation bar already say them.
A caption appears only for an exception, such as a read-only past plan or a
plan still waiting on income, and a negative balance shows as the headline in
the negative color with its minus sign. The
grounds keep their light values in dark mode, and everything on them uses
fixed ground ink: near-black for primary text and a per-ground secondary that
meets 4.5:1 on the ground and its control fill.

**Why:** A neutral screen gave the three tabs no identity. Gradient washes were
tried first and rejected: in dark mode a light-to-dark fade passes through
olive midtones, and dark versions of the grounds made tan and sage hard to tell
apart. Solid blocks with a hard edge avoid the mud, and keeping the light
values keeps each tab recognizable at night, as the weekly report tickets
already do (029). Plan's sage follows 027 because its headline is the
spendable amount.

**Constrains:** Do not give the grounds dark-mode variants or replace the hard
edge with a fade. Butter and tan are expressive here; sage is allowed only
because Plan's headline is spendable. Content on a ground uses the ground's
ink, and any appearance-dependent color placed on it, such as a state color,
must be resolved in the light appearance. Menus opened from the ground still
follow the system appearance. Settings stays neutral, with no ground.

### 031. Category is optional and starts unselected
**Date:** 2026-10-15 · **Status:** Active
**Where:** `Left/Screens/AddSpendingView.swift`, `Left/BudgetModel.swift`

Spending entry opens with no category chip selected. Logging without choosing
one saves the existing `.other` value, now labeled "Uncategorized" and still
drawn as a dashed circle. There is no "Other" chip; tapping the selected chip
clears it. Editing an entry scrolls its chosen chip into view.

**Why:** The default was a selected "Other" chip at the end of a horizontal
row, usually off-screen, so entries were silently categorized by a choice the
user never saw. Moving a highlighted "Other" to the front would make the state
visible but would still present skipping as a choice and put a solid ink chip
in front of an optional field. Since a skipped category and "Other" carry the
same information, one honest uncategorized state replaces both.

**Constrains:** Keep the stored raw value `other` for uncategorized so
existing stores and JSON backups need no migration; `.fun` displays the same
way. Category stays optional and must not block logging. Any future breakdown
by category should show uncategorized spending as its own group and treat
catch-up totals separately, since they are stored as `.other`.

### 032. Today's ground turns red below zero
**Date:** 2026-10-15 · **Status:** Superseded by 037 · **Amends:** 030
**Where:** `Left/Screens/TodayView.swift`, `Left/Screens/TodayBalanceSheet.swift`,
`Left/Components/ScreenHeader.swift`, `Left/Palette.swift`

When the displayed balance is below zero, Today's butter ground becomes a pale
negative red and the headline returns to ink, keeping its minus sign. One
caption under the headline says where the deficit goes: "This comes out of the
coming days. Tomorrow starts at −$X." On the last day of a month it says the
deficit comes out of next month; on a past day it says it came out of the days
that followed. The ground change animates and honors Reduce Motion.

**Why:** A negative-colored headline on butter read poorly, and the red number
alone did not explain what going negative means. Tomorrow's starting balance
shows the carry concretely without telling the user how to spend.

**Constrains:** The red ground is a state signal under 027, not an expressive
choice, and like every ground it keeps its light value in dark mode. Tomorrow's
figure is today's balance plus the daily rate, assuming nothing else is logged;
do not show it across a month boundary, where next month's rate may differ or
not exist yet. Compare at display precision so a fractional-cent deficit that
shows as $0.00 does not turn the ground red.

### 033. Plan amounts use the system keyboard on a short sheet
**Date:** 2026-10-23 · **Status:** Active *(not yet implemented)* · **Amends:** 014
**Where:** `Left/Components/MoneyField.swift`, `Left/Screens/IncomeSheet.swift`,
`Left/Screens/RecurringExpenseSheet.swift`, `Left/Screens/SavingsGoalSheet.swift`,
`Left/Screens/OnboardingView.swift`

Every Plan editor (income source, recurring expense, savings goal, and the
monthly income ask) is a short sheet that sits directly above the system
decimal pad. Each sheet has a title, a large amount with the caret, the name,
the controls for that type, and then the action. The onboarding setup steps for
income, recurring expenses, and savings use the same large amount and the same
keyboard. `NumpadView` is kept only for full-screen entry where the amount is
the whole job: spending, which is cents-first, and catch-up. Plan amounts are
still whole dollars and never cents-first.

**Why:** Every plan item has a name, so the system keyboard appears regardless.
Pairing it with a custom keypad would give one sheet two different typing
surfaces. A short sheet keeps the segmented controls and Save visible above the
keyboard, so no Done toolbar is needed, and it can grow to hold the savings
percentage and the recurring cadence and end month. If onboarding matches Plan,
the first amount a user enters behaves the same way as every later edit to it.
The 2026-09-21 amendment to 014 moved the recurring-expense sheet to the keypad
because the system keyboard covered its card. A short sheet that rises above
the keyboard removes that problem.

**Constrains:** Do not add a custom keypad to a plan editor. A new item opens
with the name focused, and its return key moves to the amount. A value that is
needed this month, such as an unfilled income amount, opens with the amount
focused. An existing item opens without a keyboard. Delete is available only
when editing, never when creating. Paper designs: "Plan sheets · v1 system
keyboard" and "Onboarding setup · v1 system keyboard".

### 034. Income repeats or asks each month, with no duration
**Date:** 2026-10-23 · **Status:** Active *(not yet implemented)* · **Amends:** 022
**Where:** `Left/Screens/IncomeSheet.swift`, `Left/Components/MonthDurationPicker.swift`,
`Left/BudgetModel.swift` — `IncomeSource`, `clone(for:)`

The income sheet asks one question: "Same next month" or "Ask each month". It
replaces both the "Use this amount next month too" toggle and the duration
picker. To stop a source, the user removes it. That takes it out of the current
month and every later month, and earlier months keep their own copies. When a
source asks each month, the sheet offers last month's amount as a suggestion.
It does not fill it in.

**Why:** A repeat toggle and a duration control are two answers to the question
"what happens next month?", and together they could contradict each other.
Income rarely has a known end date. When it ends, the user knows in that month
and can remove the source then. Prefilling last month's amount would let an
unchanged figure pass for a confirmed one. Gating the allowance only works if
the amount is entered.

**Constrains:** Keep `startsOn`, `endsAfter`, and `covers(month:)`, and keep
honoring them for existing stores and JSON backups. Only the income editor
stops writing them. Recurring expenses keep their cadence and their start and
end months. An explicitly entered zero is still a valid amount.

### 035. The weekly report is held out of the first release
**Date:** 2026-10-23 · **Status:** Deferred
**Where:** `Left/Screens/WeeklyReportView.swift`, `Left/Screens/TodayView.swift`

The weekly report ticket will not ship in the first App Store release.

**Why:** It is a secondary surface. The low tiers and the overspent week are
still undesigned (see PRODUCT.md), and launch effort is going into Today and
Plan.

**Constrains:** Do not extend it or design new tiers before release. Decide
whether to hide or remove it when the release work is done, and update
PRODUCT.md and APP_STORE_CHECKLIST.md at that time.

### 036. Screens are greyscale; color is kept for plan meaning and state
**Date:** 2026-10-23 · **Status:** Active *(not yet implemented)* · **Supersedes:** 030 · **Amends:** 032
**Where:** `Left/Components/ScreenHeader.swift`, `Left/Palette.swift`,
`Left/Screens/TodayView.swift`, `Left/Screens/ActivityView.swift`,
`Left/Screens/PlanView.swift`

Today, Activity, and Plan open on the same neutral grey ground. Each has the
period row and one headline number, with a hairline separating the header from
the content below. There are no butter, tan, or sage grounds. The rest of 030's
header rules still apply: one headline, no subtext in the normal state, and a
caption or pill only for an exception such as a read-only past plan or a plan
waiting on income.

**Why:** The Paper designs settled on greyscale. Tinted grounds gave each tab an
identity but competed with the headline number, and they needed their own ink
and dark-mode rules. A neutral ground keeps attention on the amount and lets
the few colors that remain stand out.

**Constrains:** 027's plan hues still apply as marks, such as the allocation bar
and onboarding's plan bar, and so do the warning and negative state colors.
Neither is used as a screen ground. 032's red ground for a negative balance is
withdrawn along with the grounds; how Today shows a balance below zero is being
redesigned. The header no longer needs fixed ground ink, and dark-mode
behavior should be decided when the grounds are removed. Paper designs: the
"main screens" and "plan screens" artboards.

### 037. Below zero, Today says "over"
**Date:** 2026-10-23 · **Status:** Active *(not yet implemented)* · **Supersedes:** 032 · **Amends:** 036
**Where:** `Left/Screens/TodayView.swift`, `Left/Screens/TodayBalanceSheet.swift`,
`Left/BudgetModel.swift`

When the displayed balance is below zero, Today's headline shows the amount
without a minus sign and replaces "left" with "over": "$23.40 over". The number
stays in ink, and only the word "over" uses the negative color. One caption
says where the deficit goes:
- If tomorrow is in the same month: "Tomorrow starts at $18.60." If tomorrow
  is still below zero: "Tomorrow starts at $22.20 over."
- On the last day of a month: "This comes out of December."
- On a past day: the deficit came out of the days that followed.

When the balance breakdown is open, it adds a line under the three steps
naming the entry where the running balance first went below zero and what was
left just before it: "Trader Joe's took you past zero. You had $49.00 left
before it." A small negative-color dot marks that entry in the list. The dot
appears only while the breakdown is open. If the day's balance was already
below zero before any entry, from carry or with nothing logged, the line says
earlier days carried it past zero and names no entry.

**Why:** Going over happens often, so it must be clear without feeling like a
penalty. "−$23.40 left" is a double negative. A large red number several times
a week reads as a scolding and dulls red for when it matters. Coloring only
the word keeps color paired with a label (027), and keeps the headline's size
and position, so going over is a different state rather than an alarm. A red
ground is gone with 036. Naming the entry that crossed zero answers the
question a negative balance raises without telling the user how to spend.

**Constrains:** Do not show a minus sign or color the number in the headline.
Compare at display precision, so a fractional-cent deficit shown as $0.00 is
not "over". Tomorrow's figure is today's balance plus the daily rate, assuming
nothing else is logged, and is never shown across a month boundary. Find the
crossing entry by walking the day's entries in the order Today lists
them, starting from the day's opening balance (carry plus allowance). Entries
logged for a past date may have no meaningful time, so the list order is the
only order there is. Mark only that one entry. The line
describes, it does not advise; do not suggest cutting back or name a
category. Paper design: "Today over · v1".

