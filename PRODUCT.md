# Left — product

Reviewed against the repository on 2026-09-19. This describes the current app;
open questions below are not committed features or launch requirements.

## Purpose

Left answers how much you can spend today from a monthly plan and the spending
you log. It is a manual budgeting tool with no accounts, bank connection,
backend, or analytics. It does not know your bank balance or whether expected
income actually arrived.

The experience is organized around three questions:

| User question | Place | Current behavior |
|---|---|---|
| What can I spend today? | Today | A prominent available balance, day navigation, that day's spending, and a balance explanation on tap |
| What happened? | Activity | Spending grouped by day within a browsable month, monthly total, and editable/deletable entries |
| What is my allowance based on? | Plan | This month's income, recurring expenses, savings goals, and an interactive daily-allowance derivation |

Settings, reached from Plan, carries privacy/support links. JSON backup and restore are development
utilities exposed only in Debug builds.

## Current behavior

### Today and the balance

The daily allowance is monthly income minus recurring expenses and savings,
divided by the number of days in the month. Unspent allowance accumulates;
spending beyond the available balance uses future allowances. A first plan
created mid-month accrues only from its first active day. Existing cross-month
carry is included in the balance.

Tapping the amount explains the day's allowance, carried-forward money, logged
spending, and remaining balance. Plan bills and savings are already deducted:
logging them again as daily spending would count them twice. The calendar and
spending meter have been removed.

### Recording and catching up

Normal spending entry is full-screen and cents-first, with an optional note and
an optional category. No category chip starts selected; spending logged without
one is uncategorized and shows a dashed icon. Tapping a selected chip clears it.
The primary flow stays open → type amount → log.

Today offers catch-up when there is a prior active day. After at least three
uncovered days, it also shows an inline prompt, then waits three days before
showing it again if there is still no entry. One total records **additional
spending not already logged** for the displayed period. It is saved once on the
period's last day and remains identifiable and editable in Today and Activity.
It does not reconstruct individual purchases or spread the amount across days.

“Nothing spent” acknowledges the period without creating spending. Currently,
closing the prompt also acknowledges it; it is not a temporary snooze. Merely
seeing the prompt does not acknowledge the gap. Gap detection uses logged dates
and acknowledgements, so it is a convenience prompt, not a guarantee that
records are complete.

### Weekly report

Held out of the first release (DECISIONS 035). The behavior below describes the
current build.

On the first open of a new Monday–Sunday week, on whatever day that is, a
ticket appears over Today showing last week's leftover: the allowance earned on
that week's active days minus the spending dated inside it. Carry and earlier
rollover are left out, so the number describes that week alone. It is rounded
down to whole dollars and paired with something that amount could buy.
“Tear it off” dismisses it. Each week is shown once and cannot be revisited;
skipped weeks do not pile up.

There is no report for a week with no active plan days, a week whose plan was
still waiting on income, or a leftover under $4, including zero and overspent
weeks, until that ticket is designed. While Today's catch-up prompt covers days
from last week, the report waits until the gap is logged or acknowledged.

### Monthly planning and income

Income sources ask whether the amount repeats next month or needs a new amount
each month. This is a planning preference per source, not a salaried/freelancer
account type or a confirmation that payment arrived. Both kinds can coexist.

Repeating amounts carry into the next monthly snapshot. A source needing a new
amount is carried as an unfilled placeholder, and the allowance waits for income
setup. Users update the current month's amounts and can review earlier monthly
plans read-only. This preserves month-to-month history; it is not a revision log
of every edit within one month.

Recurring expenses support cadences and month-based start/end dates. Savings
can have multiple named goals, each a flat amount or percentage of income.
These are amounts protected by the plan, not confirmed bank transfers.

Onboarding introduces the daily number, then guides income, recurring expenses,
and savings. It requires positive income and positive monthly spendable money;
savings may be zero. There is currently no skip-setup or demo mode.

## Vocabulary

| Term | Meaning |
|---|---|
| Daily allowance | The amount made available per active day by the monthly plan |
| Spending balance / left today | Accrued allowance plus carry, minus logged spending |
| Spending / entry | A logged purchase; stored as `Transaction` |
| Catch-up total | One spending entry covering a period; included in ordinary spending totals |
| Recurring expense | A planned repeating cost; stored as `FixedExpense`. “Bills” is also used in explanatory copy |
| Income source | A named amount used to budget for this month, not a receipt ledger |
| Amount repeats / new amount each month | Whether a source's amount is copied into the next plan |
| Savings goal | A planned amount or share of income reserved from daily spending |
| Carried forward | Earlier available money or a deficit included in today's balance |

Use “entry” when a singular noun is needed for spending; never “a spending.”
Avoid calling daily entries “expenses” where it would confuse them with planned
recurring costs. Keep the existing SwiftData model names for compatibility.

## Scope and open questions

The core remains a trustworthy daily number, fast manual entry, understandable
monthly planning, and a forgiving way to catch up. No bank connection is planned.
A widget is intended after v1 and is not required for launch.

These questions still need product decisions:

- **Large purchases:** should a dresser use accumulated spending money, a
  separate purchase fund, or another treatment? There is no separate splurge
  transaction type today; a large purchase affects the normal balance.
- **Moving money to savings:** how should users move accumulated spending money
  out of availability? Carry/allocation model fields exist, but a current
  user-facing transfer flow is not established. Do not describe this as shipped.
- **Deeper variable-income support:** monthly amounts are supported; payment
  timing, expected versus received money, and income receipt history are not.
- **Import:** natural-language entry, pasted LLM output, and bank CSV import are
  ideas. Debug JSON restore is not a transaction-import feature for users.
- **Guidance and onboarding:** contextual explainers and exploring before setup
  remain opportunities, not approved launch blockers.
- **Weekly report range:** the low tiers need more variety, because most weeks
  land under $100, and weeks under $4 or overspent need their own ticket.
- **Catch-up itself:** whether to keep catch-up at all is being reconsidered.
  It would be a larger refactor and is set aside for later.
- **Correction safety:** decide whether closing catch-up should differ from
  acknowledging no spending. Swipe deletion offers Undo (DECISIONS 031).

Record an agreed direction in DECISIONS.md before treating any of these as a
standing product rule. Release verification belongs in APP_STORE_CHECKLIST.md.
