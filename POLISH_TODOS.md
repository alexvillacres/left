# Left — polish todos

Places that feel thin or unfinished, with the problem and a proposed solution
for each. These are proposals, not committed features. Record an agreed
direction in [DECISIONS.md](DECISIONS.md) before treating any of them as a
standing product rule. Related open questions live in
[PRODUCT.md](PRODUCT.md).

Ordered roughly by priority.

## 1. Activity empty and no-plan states

**Problem.** `ActivityView.swift` shows a single grey line, "No spending this
month", when there are no entries, and a bare "No plan yet" with no plan. Today
has an illustrated empty state, so the middle tab looks unfinished beside it.
New users land here right after onboarding.

**Solution.** Give Activity an empty state in the same voice and visual language
as Today's: a small illustration, one sentence on what will appear here, and a
pointer back to Today's + button. Treat "No plan yet" the same way, with a route
into setup.

## 2. Undo for deleted entries

**Problem.** Deleting a spending entry has no Undo or confirmation. An
accidental swipe silently changes the balance the app is built around.
PRODUCT.md lists correction safety as undecided.

**Solution.** Prefer a brief "Entry deleted · Undo" over a confirmation dialog,
which suits the app's forgiving tone and keeps deletion fast. Decide separately
whether closing a catch-up should differ from acknowledging no spending.

## 3. Overspent and near-zero states

**Problem.** The app celebrates good days and weeks and says little about bad
ones. Going negative today has no dedicated moment, and the weekly report has no
ticket for weeks under $4 or overspent weeks. Most weeks also land under $100,
so the low tiers need more variety.

**Solution.** Add a calm, non-judgmental treatment for going negative, using the
warning/negative colors only to signal state (DECISIONS 027, 029, 030). Add
weekly report tickets for under-$4 and overspent weeks, and more variety across
the low tiers.

## 4. Moving surplus to savings

**Problem.** Carry and allocation fields exist in the model, but there is no
user-facing way to move accumulated spending money out of availability. Surplus
piles up in the balance with nowhere to go. This is the largest functional gap.

**Solution.** Decide the model first: allocate from carry into a savings goal,
a separate purchase fund, or something else. This overlaps with the "large
purchases" open question. Preserve existing `carriedGross` and allocation state,
and do not describe it as shipped until a flow exists.

## 5. Activity as feedback, not just a ledger

**Problem.** Activity is a month total plus a list. There is nothing that helps
someone notice a pattern, and no search or filter.

**Solution.** Keep it restrained: one or two derived lines such as busiest day or
average per day against the daily rate, computed from the model rather than a
parallel formula in the view. Search and filter can come later if the list grows
unwieldy.

## 6. First day after onboarding

**Problem.** Onboarding explains the promise, then setup, and the first Today
screen has to teach that the balance is based on the plan and logged spending,
not a bank balance. That relies on someone tapping the balance to find the
explanation. PRODUCT.md lists contextual explainers and exploring before setup
as opportunities.

**Solution.** Add a light, dismissible first-run hint on Today pointing at the
balance and the + button. Optionally let people look around before finishing
setup.

## 7. Settings

**Problem.** Settings is two links, a data note, and a version number. That is
intentional, but it feels sparse.

**Solution.** Keep it from becoming a preferences panel. If anything is added,
limit it to things that earn their place, such as a daily reminder time or a
short "how the daily number works" explainer.
