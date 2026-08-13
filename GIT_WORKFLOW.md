# Git workflow

Solo repo, one remote (`origin`, `github.com:alexvillacres/left`), no CI. The
process below is deliberately light — but the commit and tag messages are not,
because they are the only durable record of *why* this app looks the way it
does.

The house style already exists in this repo. Commit `50ffcbe` is the model.
Every commit should read like that one.

---

## Start here: the three places

Git has three places, not one. Nearly every beginner confusion comes from not
seeing this:

| Place | What it is | Where you see it |
|---|---|---|
| **Working tree** | The actual files on disk | What Xcode edits when you type |
| **Staging area** (the "index") | A draft of your next commit | `git diff --cached` |
| **History** | Sealed, permanent commits | `git log` |

Your desk (working tree) → the box you are packing (staging) → the shelf of
labelled boxes (history).

`git add` looks like bureaucracy before `git commit`. It is the opposite:
**staging is the feature.** It is what lets one messy working tree become
several clean commits without editing a line of code — put a few things in the
box, seal it, put a few more in, seal that. The files on disk never change.

This also explains the command that trips up everyone:

```sh
git diff            # desk vs box   — what you have NOT staged
git diff --cached   # box vs shelf  — what you HAVE staged
```

If you `git add` a file and then `git diff` shows nothing, that is why. It is
not broken.

### Reviewing: zoom out before you zoom in

Three levels, in this order. Raw diffs are the *last* question you ask, not the
first:

```sh
git status --short              # 1. WHICH files changed
git diff --stat                 # 2. HOW MUCH changed in each
git diff Left/Palette.swift     # 3. WHAT exactly changed, in one file
```

Levels 1 and 2 are where you should live. Level 3 is for a file you are
specifically suspicious about. Reading a 980-line diff top to bottom is almost
always the wrong move.

Better than any terminal diff, in order of value:

1. **Xcode's change bars**, while you work. The blue marks in the editor gutter;
   click one for "Show Change." `⌥⌘C` opens the Source Control navigator. Most
   reviewing should happen here, continuously — not in a terminal at the end.
2. **A GitHub PR**, for reviewing a finished chunk. Worth it even solo:
   collapsible files, comments, and "viewed" checkboxes beat anything local.

   ```sh
   git switch -c feature/thing
   # ... work, commit ...
   git push -u origin feature/thing
   gh pr create --fill && gh pr view --web
   ```
3. **`delta`**, if you want terminal diffs to be readable:
   `brew install git-delta && git config --global core.pager delta`

### The daily loop

```sh
git status --short                       # what is already dirty
# ... make ONE coherent change in Xcode ...
git add Left/Screens/SettingsView.swift  # name files explicitly
git diff --cached                        # read what you are about to seal
git commit                               # editor opens for a real message
```

Two rules that would have prevented every problem found on 2026-08-13:

- **Never `git add -A` or `git add .`** — that is how unrelated work gets swept
  into a commit. Name the files.
- **Build before you commit**, not after.

The deeper habit is simply committing more often. The reason this repo
accumulated seventeen dirty files across a week — and hid a broken `main` inside
them — was not a missing tool. If you can describe what you did in one sentence
without the word "and," commit it now.

### Do not learn these yet

`rebase`, `cherry-pick`, `reset --hard`, `push --force`, submodules. None are
needed on a solo repo, and the last two are the ones that actually destroy work.

### The safety net

Committed work is almost never truly lost. If you panic:

```sh
git reflog          # every position HEAD has been in, with SHAs
git checkout <sha>  # go look at one
```

The genuine danger zone is **uncommitted** work, which nothing can recover.
One more reason to commit often.

### Aliases worth setting

```sh
git config --global alias.s "status --short"
git config --global alias.l "log --oneline --graph -15"
git config --global alias.staged "diff --cached"
git config --global alias.last "show --stat HEAD"
```

---

## Branches

| Branch | Purpose |
|---|---|
| `main` | Always builds and runs. Never force-pushed. |
| `feature/<thing>` | Anything that touches more than one screen or lasts more than a day. |
| `fix/<thing>` | A defect with a known cause. |

Small, obvious, self-contained work can go straight to `main` — this is a solo
repo and a branch for a one-line color fix is ceremony. Anything you would want
to abandon halfway gets a branch.

Delete the branch after merging. Two stale branches are sitting in this repo
right now (`add-spending-iteration`, `feature/today-meter`); see
[Cleanup](#immediate-cleanup).

**Merging:** `--no-ff` into `main`, so the feature's commits stay grouped and
the merge commit can summarize the arc.

```sh
git switch main
git merge --no-ff feature/today-meter
git branch -d feature/today-meter
git push origin main --delete-if-you-pushed-the-branch  # or: git push origin :feature/today-meter
```

**Rebasing:** rebase your own unpushed work freely to clean it up before
merging. Never rebase anything already on `origin/main`.

---

## Commits

### Size

One decision per commit. If the body needs the word "also" more than once, it
should have been two commits. `50ffcbe` legitimately earns its "Also fixes…"
line — a one-line dark-mode bug found while doing the main work — but that is
the ceiling, not the target.

Never commit a state that does not build. "Checkpoint current app redesign" is
in this history; it should not happen again.

### Format

```
Short imperative subject, ≤ 60 chars, no trailing period

Why the change was needed. Lead with the problem, not the solution — what was
broken, wrong, or in the way. Be concrete: name the symptom you actually saw.

What the change does about it, and specifically what it removed or made
impossible. Prose, wrapped at 72 columns. No bullet lists unless there is
genuinely an unordered set.

If an obvious alternative was rejected, say which one and why it lost. This is
the sentence future-you will actually want.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

**Subject line rules**

- Imperative mood: "Make palette appearance-aware", not "Made" or "Making".
- Name the thing, not the file: "Improve history navigation", not "Update
  MonthView.swift".
- No type prefixes (`feat:`, `fix:`). This repo does not generate a changelog
  from commits; tags do that job.

**Bodies are required** for anything that changes behavior or appearance.
Genuinely trivial commits (a typo, a bumped constant with an obvious reason
in the subject) may go without one.

**Bad, from this repo's actual history:**

```
Touched up design and adjusted flow and functionality.
```

Three unrelated changes, no body, past tense, tells you nothing six months
later.

**Good, from this repo's actual history** — `git show 50ffcbe --stat`. Read it
before writing a commit message here.

### Trailers

- `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` on any commit where
  Claude wrote a meaningful share of the code.
- `Decision: NNN` when the commit implements or reverses an entry in
  `DECISIONS.md`. Makes `git log --grep='Decision: 008'` work.

### The relationship to DECISIONS.md

A commit body explains *this change*. `DECISIONS.md` explains *the standing
rule*. Most commits need only the former. When a commit establishes something
that constrains future work — "never call `.opacity()` on a meter fill" — write
the entry too, in the same commit, and reference it with the `Decision:`
trailer.

---

## Pre-v1 tags

No tags exist yet. Everything before the first App Store release is `v0.x.y`,
annotated, on `main`.

### Scheme

- **`v0.MINOR.0`** — a milestone worth showing someone. A screen is finished, a
  model change lands, a redesign settles.
- **`v0.MINOR.PATCH`** — fixes on top of a milestone with no new capability.
- **`v1.0.0`** — the first App Store submission. Not before. `v0.x` means the
  data model may still change under you.

Suggested starting point, since the current history is ahead of the tags:

| Tag | Covers |
|---|---|
| `v0.1.0` | The working app: plan, today, spending entry, month grid |
| `v0.2.0` | The redesign — floating tab bar, today meter, semantic palette |
| `v0.3.0` | Income sources and multiple savings goals |
| `v0.4.0` | The current uncommitted work, once it lands |

Tag retroactively at those commits, or start clean at `v0.4.0` — the point is
that every tag from here forward has a real message.

### Tag messages

An annotated tag is the release note. It is written for a human — often a
TestFlight tester — not for a machine.

```sh
git tag -a v0.4.0
```

Opens your editor. Write:

```
v0.4.0 — Settings, store recovery, App Store prep

One-paragraph summary of what this build is for. What can you do now that you
could not do at the last tag? If it exists to unblock something (a submission,
a tester), say so.

Added
  - Settings screen with Privacy and Support links, required by App Review.
  - Store recovery screen: an unopenable database now explains itself and
    offers a reset instead of crashing.

Changed
  - Month duration is now picked explicitly rather than inferred.

Fixed
  - Selected category chip was invisible in dark mode.

Known issues
  - Legacy scalar income fields still present on MonthPlan; removed after the
    first release.

Data
  - No schema change. / Adds IncomeSource; existing plans migrate lazily on
    first launch of the current month.

Decisions: 016, 017
```

**The `Data` section is not optional on any tag that touches
`BudgetModel.swift`.** Whether a build can read the previous build's store is
the single most useful thing a tag can tell you, and the only way to know
whether a tester needs to delete the app.

Keep `Known issues` honest. A tag that claims everything works is worth nothing
when the next one has to admit it didn't.

### Cutting a release

```sh
# 1. Confirm you are on a clean main that builds in Xcode.
git switch main && git status
git pull --ff-only

# 2. Bump MARKETING_VERSION / CURRENT_PROJECT_VERSION in Xcode, commit.
git commit -am "Bump version to 0.4.0"

# 3. Tag, with the full message above.
git tag -a v0.4.0

# 4. Push commits and the tag.
git push origin main
git push origin v0.4.0

# 5. Verify.
git show v0.4.0
```

Never move or delete a pushed tag. A wrong tag is superseded by the next one,
with a line in its message saying so.

### Reading history later

```sh
git tag -n99                       # every tag with its full message
git log v0.2.0..v0.3.0 --oneline   # what shipped between two builds
git log --grep='Decision: 008'     # every commit touching a standing decision
git show 50ffcbe                   # the reference commit message
```

---

## Before you commit

There are no tests in this repo — `AGENTS.md` says leave the template test
targets alone, and that stands. The checks are therefore manual and short:

1. It builds. From the terminal:

   ```sh
   xcodebuild -project Left.xcodeproj -scheme Left \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -configuration Debug build 2>&1 | tail -5
   ```
2. You ran the affected screen in **both** light and dark mode. Decision 008
   exists because this step was skipped once.
3. Dynamic Type at a large size, if you touched layout.
4. `git diff --staged` reads like the commit message you are about to write.

---

## Verifying a commit builds

The working tree contains everything you are *about* to commit, so building it
proves nothing about the commit itself. Build the commit in a throwaway
worktree instead:

```sh
git worktree add /tmp/left-verify HEAD --detach
cd /tmp/left-verify
xcodebuild -project Left.xcodeproj -scheme Left \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug -derivedDataPath /tmp/left-dd build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
cd - && git worktree remove /tmp/left-verify --force
```

This is how `c3c0f2e` was caught: it referenced `SavingsAllocation`,
`StoreRecoveryView`, `SettingsView`, `SegmentedControl` and half a dozen model
properties that were still sitting uncommitted, so `main` did not compile for
eight days without anyone noticing. The working tree built fine the whole time.

## Splitting a messy working tree

When one file holds two unrelated changes, stage it in pieces rather than
committing both together. Start with the interactive version:

```sh
git add -p Left/BudgetModel.swift
```

Git walks you through each chunk asking `Stage this hunk [y,n,q,a,d,s,e,?]`.
Press `y` to include it, `n` to skip, `s` to split the chunk into smaller ones,
`e` to edit it by hand, `?` for the full list. This handles most cases.

When a single chunk mixes both changes and `s` will not split it far enough,
dump the diff, delete the hunks you do not want, and stage what is left:

```sh
git diff Left/BudgetModel.swift > /tmp/bm.patch
grep -n '^@@' /tmp/bm.patch          # find hunk boundaries
$EDITOR /tmp/bm.patch                # keep only the hunks for this commit
git apply --cached --recount /tmp/bm.patch
```

`--recount` fixes the line arithmetic in the `@@` headers so you can edit hunks
freely, including splitting one in half. The working tree is untouched — only
the index changes — so the rest of the work stays exactly where it was.

Verify the split landed where you meant before committing:

```sh
git diff --cached --stat     # what is going in
git diff --stat              # what is staying behind
```

## Documents in this repo

| File | What it is | When to edit |
|---|---|---|
| `AGENTS.md` | The brief. What the app is and the rules it is built under. `CLAUDE.md` is a symlink to it — edit `AGENTS.md`. | Rarely. When a rule genuinely changes. |
| `DECISIONS.md` | Why the app is the way it is. Numbered, permanent. | Whenever a decision constrains future work. |
| `NAMING.md` | The spending / recurring-expense vocabulary split. | When user-facing vocabulary changes. |
| `APP_STORE_CHECKLIST.md` | Submission requirements and their status. | As items land. |
| `GIT_WORKFLOW.md` | This file. | When the process changes. |

---

---

## Immediate cleanup

As of 2026-08-13:

1. **Two stale branches** — `add-spending-iteration` and `feature/today-meter`,
   both confirmed merged into `main`. Delete them:
   `git branch -d add-spending-iteration feature/today-meter`
2. **No tags.** Cut `v0.1.0`–`v0.3.0` retroactively, or start at `v0.4.0`.
3. **A stale stash** — `stash@{0}` holds a pre-split backup whose
   `LeftApp`/`TodayView`/`PlanView`/`FloatingTabBar` are older than `main`.
   Drop it once you are satisfied with the history: `git stash drop`.
