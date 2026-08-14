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

Every entry links to the code so this file can never be the only copy.

## Template

```markdown
### NNN. Short imperative title
**Date:** YYYY-MM-DD · **Status:** Active | Superseded by NNN | Deferred
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
**Date:** 2026-08-05 · **Status:** Active *(reconstructed)*
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

**Constrains:** These three are the *only* stored money state. Adding a fourth
should feel hard.

### 003. Snapshot the plan per month
**Date:** 2026-07-02 · **Status:** Active
**Where:** `Left/BudgetModel.swift` — `MonthPlan`, `nextMonth()`

One `MonthPlan` record per calendar month, holding its own copy of income,
expenses, and savings target. Edits apply to the current month only.

**Why:** Past months stay historically accurate when income changes. A single
mutable plan would silently rewrite every previous month's daily rate the moment
you got a raise.

**Constrains:** `nextMonth()` is the one clone path, used for both adjacent
months and gaps. Per-source affirmation deliberately does not carry — inherited
variable income has not been vouched for in the new month.

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
**Date:** 2026-08-05 · **Status:** Active *(reconstructed)*
**Where:** `Left/BudgetModel.swift` — `income`, plan-level `cadence`,
plan-level affirmation timestamp

Income became a collection of `IncomeSource`s, and savings became multiple
goals. The old plan-level scalars stay on the model, read only by plans written
before the change, and migrate lazily.

**Why:** A SwiftData schema migration on a shipping app is a real risk for a
cosmetic gain. Lazy migration means an old store opens and works, and the
current month materializes its legacy scalar as an `IncomeSource` when touched.

**Constrains:** New code reads sources, never the scalars. Any field commented
"legacy" is read-only and awaiting deletion after the first App Store release.

### 006. Do not rename the `@Model` types
**Date:** 2026-07-31 · **Status:** Active
**Where:** `Left/BudgetModel.swift`, `NAMING.md`

`Transaction` and `FixedExpense` keep their names even though the UI now says
"spending" and "recurring expense."

**Why:** Renaming a SwiftData model class means a store migration. Neither name
is ever shown to a user, so the translation cost is one row of a table in
`NAMING.md`; the migration cost is real.

---

## Vocabulary

### 007. "Spending" for daily, "recurring expense" for fixed
**Date:** 2026-07-31 · **Status:** Active
**Where:** `NAMING.md` (full rationale), all user-facing strings

The unqualified word "expense" belongs to the recurring side only.

**Why:** "Transaction" matches the type name but is bank-statement vocabulary on
the button pressed five times a day. "Recurring" over "fixed" frees "fixed" to
mean exactly one thing (`IncomeCadence.fixed` — income that doesn't vary).
"Recurring" over "bills" because savings transfers in that list are not bills.

**Constrains:** "Spending" is a mass noun with no singular, so the daily side
avoids naming an individual item. Destructive action is "Delete", not "Delete
expense". If a screen ever needs the singular, solve it then — do not reach for
"expense". See `NAMING.md` for what deliberately did not change.

---

## Visual system

### 008. The palette exposes intent, never hue
**Date:** 2026-08-04 · **Status:** Active
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
**Date:** 2026-08-04 · **Status:** Active
**Where:** `Left/Palette.swift`

**Why:** If every state is colored, no state is legible at a glance. Being fine
is the common case and deserves no visual weight; the two states worth noticing
keep their semantic color.

### 010. Ship a custom floating tab bar instead of `TabView`
**Date:** 2026-08-04 · **Status:** Active
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
**Date:** 2026-07-31 · **Status:** Active
**Where:** `Left/Screens/TodayView.swift`, `NAMING.md`

Fixed `.system(size: 24, weight: .semibold)` rather than the app's scaling
`.dmSans`.

**Why:** It is an icon inside a fixed-size 56pt circle. Growing it clips it.
This is the only correct place in the app for a non-scaling size — everywhere
else, a fixed font size is a bug.

### 013. The today meter replaced the week strip
**Date:** 2026-08-03 · **Status:** Active *(reconstructed)*
**Where:** `Left/Components/TodayMeter.swift`

**Why:** The strip showed seven days at once on a screen whose entire job is
today. The meter answers the only question being asked. Its fill moves through
the semantic palette as the budget is used; the final red overlay stays
partially transparent over warning amber, producing an orange-red nub just
before depletion rather than a hard color flip.

---

## Interaction

### 014. Cents-first entry belongs to `NumpadView` and nowhere else
**Date:** 2026-07-15 · **Status:** Active
**Where:** `Left/Components/NumpadView.swift`, `Left/Components/MoneyField.swift`

`NumpadView` is for logging spending — the thing done five times a day, where
typing `650` means $6.50. `MoneyField` uses the **system** decimal pad, where
`650` means 650.

**Why:** Cents-first buys real speed on the high-frequency action. On plan
values set a few times a year inside a scrolling form, selection, paste, and
free dismissal matter more, and a surprising interpretation of a typed number is
a bug waiting to happen.

**Constrains:** Do not "unify" these two. The split is the decision.

### 015. Spending entry is full-screen, and the note is a pushed screen
**Date:** 2026-08-04 · **Status:** Active
**Where:** `Left/Screens/AddSpendingView.swift`

`AddSpendingSheet` became `AddSpendingView`, presented full-screen with no
detents. The optional note moved to its own pushed screen.

**Why:** The two detents existed solely so the sheet could shrink for the note
field's keyboard — and the numpad needs no keyboard at all. Moving the note to a
screen where the keyboard has room removed both detents, their computed heights,
the focus-driven resize, and a double keyboard-inset workaround.

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
**Date:** 2026-08-11 · **Status:** Active
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
**Date:** 2026-08-14 · **Status:** Active
**Where:** `Left/Components/DerivationBar.swift`, Plan editor sheets

Action sheets use the app's custom header and paint
`Color(uiColor: .systemBackground)` edge to edge, including an explicit solid
presentation background.

**Why:** Allowing the system presentation or navigation surface to show through
introduces Apple's glass treatment, which does not match the app's quiet,
solid-surface sheet language.

**Constrains:** New action sheets must provide their own opaque background and
must not rely on built-in glass navigation chrome for their primary surface.
