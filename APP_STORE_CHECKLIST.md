# Left — launch checklist

Repository review: 2026-09-19. Checked implementation items below were confirmed
from source/configuration, not from a new build or device run. Verification boxes
remain unchecked until performed on the intended release candidate. Previous
build results do not certify the current app. Product ideas live in
[PRODUCT.md](PRODUCT.md#scope-and-open-questions).

## Implemented baseline

- [x] Today balance and tap-to-review explanation.
- [x] Activity month/day spending history with editing and deletion.
- [x] Monthly Plan editing, read-only past plans, and pinned interactive derivation.
- [x] Repeating income amounts and fresh monthly amount placeholders.
- [x] Full-screen cents-first entry and editable catch-up totals.
- [x] Catch-up acknowledgement without a zero-value spending transaction.
- [x] Intro and monthly onboarding, gated on completion; positive income and
      spendable amount required, zero savings allowed.
- [x] Month creation and carry reconciliation on launch/foreground.
- [x] Store-recovery screen with retry and confirmed reset instead of a crash
      or silent in-memory fallback.
- [x] Privacy and Support rows in Settings. Public destinations still require
      verification below.
- [x] Debug-only JSON backup/restore; excluded from the release product.
- [x] Primary icon configured as `LeftApp.png`; no custom appearance variants.
- [x] App target set to iOS 17.0 and iPhone-only; portrait orientation configured.
      Project/test deployment settings still include 26.5; do not confuse these
      with the app target's minimum OS.
- [x] `ITSAppUsesNonExemptEncryption` configured as false. Confirm submission
      answers against the final build and current distribution requirements.

## Release configuration and external prerequisites

- [ ] Confirm `com.villacres.left` is the intended app bundle ID and matches
      signing and the App Store Connect record. This replaces the old documented
      `goodjobstudios.Left` identifier.
- [ ] Confirm app name availability and active developer membership.
- [ ] Confirm minimum OS, device support, portrait-only behavior, and whether
      “Designed for iPhone” Mac availability is desired in App Store Connect.
- [ ] Build the current Release configuration and verify the built app's minimum
      OS, device family, orientation, and encryption declaration.
- [ ] Confirm version/build numbers before upload. Source currently says 1.0 (1).
- [ ] Publish and verify the Privacy Policy and Support destinations configured
      in `SettingsView.swift`: `https://goodjobstudios.com/left/privacy` and
      `https://goodjobstudios.com/left/support`. Their availability was not checked
      during this documentation review.
- [ ] Ensure privacy copy accurately describes local storage, deletion, and the
      shipping feature set; confirm App Privacy answers for the submitted build.
- [ ] Verify font/asset rights and include required license notices. DM Sans font
      files are bundled; licensing completion is not established by this review.

## Core flow verification on the release candidate

- [ ] Fresh physical-device install → intro → monthly setup → Today → log
      spending → balance updates → force-quit/relaunch → data persists.
- [ ] Quit during each onboarding step and confirm setup remains recoverable;
      complete onboarding and confirm it does not reappear unexpectedly.
- [ ] Log spending comfortably in under three seconds; verify note, category,
      date, and cents-first entry, including zero and large values.
- [ ] Edit and delete spending from Today and Activity; verify totals and balance.
- [ ] Verify transaction swipes do not accidentally navigate between days.
- [ ] Confirm Today explanation adds up at displayed currency precision for
      positive/negative carry, fractional daily rates, and past dates.
- [ ] Verify catch-up after three uncovered days, manual entry, editing, and
      relaunch persistence. Confirm the total is counted once on the end date.
- [ ] Verify “Nothing spent” and close acknowledge the period without changing
      spending; distinguish this behavior from a temporary snooze in review.
- [ ] Verify monthly income edits, mixed repeating/new-month sources, missing
      amounts, explicit zero, and read-only past Plan navigation.
- [ ] Verify recurring-expense cadences and start/end months; flat and percentage
      savings goals; plans whose costs approach or exceed income.
- [ ] Verify the first plan started mid-month accrues only active days at the
      normal daily rate.
- [ ] Verify month boundaries, skipped months, income placeholders, and carry
      reconciliation, including a later edit to a previous month's spending.
- [ ] Verify foregrounding after midnight, time-zone changes, and regional
      formatting. USD is currently the fixed currency; confirm that v1 scope.
- [ ] Verify opening an existing store after the model changes and recovery from
      a store-open failure on disposable data.
- [ ] Decide whether immediate deletion needs Undo or confirmation before launch.

## Appearance and accessibility

- [ ] Check Today, Activity, Plan, onboarding, Settings, and every entry/editor
      sheet in light and dark mode on supported iPhone sizes.
- [ ] Check large accessibility text sizes and long names/amounts.
- [ ] Run VoiceOver through navigation, balance explanation, forms, keypad,
      catch-up, and spoken currency values.
- [ ] Verify every interactive control has at least a 44-point touch target,
      including catch-up prompt actions and dismissal.
- [ ] Verify Reduce Motion and understandable numeric updates without animation.
- [ ] Confirm meaningful states are conveyed through text, not color alone.

## App Store Connect and product page

Verify current platform requirements while preparing the submission; this file
is a task list, not a substitute for App Store Connect's current requirements.

- [ ] Create/confirm app record, bundle ID, SKU, name, subtitle, description,
      keywords, category, age rating, and copyright.
- [ ] Set privacy/support URLs, review contact details, and useful review notes.
- [ ] Confirm privacy and export-compliance answers, distribution territories,
      pricing, and applicable trader-status information.
- [ ] Complete applicable agreements, tax, and banking setup if paid.
- [ ] Capture clean screenshots with realistic nonpersonal sample data showing
      Today, spending entry, Activity, and Plan; no removed meter/calendar.
- [ ] Upload required screenshot sizes and verify all copy matches the build.
- [ ] Decide whether an optional app preview is worthwhile.

## TestFlight and submission

- [ ] Archive the exact intended commit from a clean release working tree.
- [ ] Validate the signed archive and resolve Organizer errors/warnings.
- [ ] Upload and distribute through TestFlight.
- [ ] Have someone other than the developer complete setup and daily logging,
      interpret the balance, and resume after missed logging.
- [ ] Recheck release metadata, screenshots, privacy answers, and availability.
- [ ] Select the processed build, submit for review, and monitor review messages.

## Development verification notes

Fresh-install testing erases local data; use a disposable simulator/device or
preserve needed development data first. Deleting the app clears its store and
onboarding completion flag. The current simulator uninstall command is:

```sh
xcrun simctl uninstall booted com.villacres.left
```

Run again from Xcode to see the intro and monthly setup. A zero-value plan may
exist during setup; the completion flag still gates onboarding.

Debug launch argument `-showCatchUpPrompt` exposes the catch-up prompt for visual
review. Also verify normal date-driven behavior without that argument.

JSON backup/restore checks belong to development verification: round-trip plans,
relationships, catch-up ranges and acknowledgement; confirm these controls are
absent from Release. Debug backup styling is not a public launch requirement.
