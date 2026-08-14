# Left — App Store Launch Checklist

_Last audited against the working tree on 2026-08-11 (branch `main`, uncommitted
changes present). Notes marked **Status** record what the code actually does
today; unchecked boxes with a status note mean the code is in place but the
item still needs a decision or a real-device test._

## Release blockers

- [x] Add a 1024×1024 primary app icon to `Assets.xcassets/AppIcon.appiconset`.
      **Status:** `left-logo.png` is in place as the universal 1024×1024 icon.
- [x] Add dark and tinted app icon variants, if desired.
      **Status:** resolved by removing the two empty appearance slots from
      `Contents.json` — they had no `filename` and did nothing. iOS 18+
      auto-generates the tinted icon from the primary. Re-add the slots if real
      variants are ever drawn.
- [x] Change the deployment target from iOS/iPadOS 26.5 to the intended minimum (the product brief specifies iOS 17).
      **Status:** app target is `17.0`. Note the *project-level* setting and both
      test targets are still `26.5`; the app target overrides it, so the shipped
      binary is correct, but a newly added target would inherit 26.5.
- [x] Confirm the Release configuration builds successfully after lowering the deployment target.
      **Status:** clean Release build succeeds at 17.0 with no errors and no
      availability warnings. `PlistBuddy` against the built `Left.app` confirms
      `MinimumOSVersion 17.0`, `UIDeviceFamily [1]`, portrait-only, and
      `ITSAppUsesNonExemptEncryption false`.
- [ ] Confirm the final bundle identifier (`goodjobstudios.Left`) before the first upload.
      **Status:** app target is `goodjobstudios.Left`; the two test targets use
      `goodjobstudio.LeftTests` / `goodjobstudio.LeftUITests` (no trailing “s”).
      Harmless for submission, but worth aligning.
- [ ] Confirm the app name “Left” is available in App Store Connect.

## Onboarding and plan validation

- [x] Keep presenting onboarding until setup has actually been completed.
      **Status:** `AppRoot` gates on a `hasCompletedOnboarding` `@AppStorage`
      flag, set only when the savings step finishes, and
      `.interactiveDismissDisabled(isOnboarding)` blocks swipe-to-dismiss.
- [x] Disable onboarding progression until monthly income is greater than zero.
      **Status:** `canContinueOnboarding` requires `plan.incomeTotal > 0` on the
      income step.
- [x] Require monthly spendable income to be greater than zero:
      `income − fixed expenses − savings goal > 0`.
      **Status:** enforced on the savings step via `plan.monthlySpendable > 0`.
- [ ] Test quitting during onboarding and relaunching.
- [ ] Test completing onboarding and relaunching.
- [ ] Verify the completed plan persists after force-quitting.

## Core product readiness

- [ ] Add the always-visible Plan derivation:
      `income − fixed expenses − savings = spendable ÷ days = daily rate`.
      **Status:** `DerivationBar` exists and is fully built (including a
      VoiceOver label and live previewing of unsaved values), but it is only
      shown inside the income sheet and the recurring-expense sheet. The Plan
      root shows three summary rows with no pinned derivation, and the savings
      sheet does not show it either.
- [x] Apply the intended positive, warning, and negative colors to the Today hero amount.
      **Status:** resolved as a deliberate design change rather than as
      specified — the hero renders in `.primary`, and state is carried by the
      status chip (`leftPositive` / `leftNegative` fills) and by `TodayMeter`,
      which ramps warning→negative as the day's budget is consumed. Note that
      `Color.leftPositive` is intentionally an achromatic gray, not teal.
- [x] Add or deliberately remove the month-progress footer and net-position summary from the product scope.
      **Status:** deliberately removed. `TodayMeter` plus the yesterday-delta
      status chip replace the “Day 14 of 31 / $41 ahead” footer; month-level
      totals and `projectedSavings()` live in the MonthView header instead.
- [ ] Verify that transaction swipe-to-delete does not also trigger day navigation.
      **Status:** `TodayView` attaches `daySwipeGesture` as a
      `.simultaneousGesture` on the whole screen, requiring >50pt of horizontal
      travel and horizontal dominance; the list rows use `.swipeActions`. The
      guard is plausible but has not been confirmed by hand.
- [ ] Decide whether deleted transactions and fixed expenses need confirmation or Undo.
      **Status:** deletes are immediate everywhere (TodayView, MonthView day
      sheet, Plan editors). No confirmation, no undo.
- [ ] Verify month-boundary plan creation on launch and when returning to the foreground.
      **Status:** implemented — `AppRoot.ensurePlan()` runs in `.task` and on
      `scenePhase == .active`, clones the previous plan for the new month, and
      `reconcileCarryover` refreshes `carriedGross` from the prior month's
      `endingSurplus()`. Needs runtime verification.
- [ ] Verify rollover calculations across the last and first days of a month.
- [x] Decide how the app should recover if its local SwiftData store cannot be opened.
      **Status:** the `fatalError` is gone. `PersistentStore.load()` returns a
      `Result`; on failure `LeftApp` shows `StoreRecoveryView` with “Try again”
      and a confirmed “Start over” that erases the store and its `-wal`/`-shm`
      sidecars. Deliberately does *not* fall back to an in-memory store, which
      would look normal while silently discarding everything entered.
      **Verified on simulator:** a deliberately corrupted `default.store`
      produces the recovery screen instead of a launch crash, and removing the
      three store files lets the app rebuild and land on onboarding.

## Supported devices and accessibility

- [x] Decide whether v1 is iPhone-only or supports both iPhone and iPad.
      **Status:** iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), plus Mac via
      “Designed for iPhone” (a Pricing and Availability checkbox in App Store
      Connect, not a build setting). No Catalyst, no visionOS.
- [x] Decide whether v1 supports landscape or portrait only.
      **Status:** portrait only. The dead `UISupportedInterfaceOrientations~ipad`
      array was removed from `Info.plist`.
- [x] ~~If iPad is supported, test every screen on small and large iPads.~~
      Not applicable — iPhone-only.
- [x] ~~If landscape is supported, test every screen and sheet in landscape.~~
      Not applicable — portrait only.
- [ ] Test Light Mode and Dark Mode.
      **Status:** every custom color in `Palette.swift` resolves per appearance
      through a dynamic `UIColor`, so the groundwork is done; a visual pass has
      not been run.
- [ ] Test the largest Dynamic Type accessibility sizes.
      **Status:** `dmSans(_:relativeTo:)` scales with Dynamic Type, and the
      calendar cells use `minimumScaleFactor`. Not yet tested at AX sizes.
- [ ] Test VoiceOver navigation and spoken currency values.
      **Status:** ~37 `accessibilityLabel` calls across the app, spoken currency
      in the derivation bar and calendar cells, and named accessibility actions
      for day/month navigation. Needs a real VoiceOver run.
- [ ] Make calendar outcomes understandable without relying only on color.
      **Status:** cell tint is the only visual signal; the spent amount is
      exposed to VoiceOver only.
- [ ] Verify every interactive control has at least a 44×44-point hit area.
      **Status:** month-nav buttons, calendar cells, chips, and the income
      confirm row all set `minHeight: 44` / `44×44` explicitly. Worth a sweep of
      the remaining Plan rows and sheet controls.
- [ ] Test Reduce Motion and confirm numeric updates remain understandable.
      **Status:** `accessibilityReduceMotion` is honored in TodayView,
      MonthView, PlanView, SavingsGoalSheet, and FloatingTabBar — every spring
      animation becomes `nil`. Not yet tested end to end.

## Privacy, support, and legal

- [ ] Publish a public privacy-policy webpage.
- [ ] Explain that budget and transaction data stays on the device.
- [ ] Explain retention and deletion behavior, including that deleting the app removes local data.
- [x] Add an easily accessible Privacy Policy link inside the app.
      **Status:** built in `SettingsView` as a tappable row. **Blocked on the URL
      above** — it currently points at a placeholder in `ExternalLink`.
- [ ] Publish a support webpage or support contact page.
- [x] Add an easily accessible Support link inside the app.
      **Status:** built in `SettingsView` alongside Privacy, same placeholder
      URL caveat. Both URLs live in one `ExternalLink` enum at the top of the file.
- [ ] Confirm App Privacy answers in App Store Connect. With the current local-only architecture and no analytics, “Data Not Collected” is likely appropriate.
      **Status:** still accurate — no network code, no third-party SDKs, no
      dependencies.
- [ ] Confirm rights and licenses for all bundled fonts and other assets.
      **Status:** three DM Sans weights are bundled (`Left/Fonts`) and declared
      under `UIAppFonts`. DM Sans ships under the SIL Open Font License, which
      permits embedding, but no license file is included in the repo or app.
- [x] Complete export-compliance questions. The app currently appears to use no custom encryption.
      **Status:** `ITSAppUsesNonExemptEncryption` is set to `false` in
      `Info.plist` and verified in the built app, so uploads will no longer
      prompt for it.
- [ ] Complete Digital Services Act trader-status information for EU distribution.

## App Store Connect

- [ ] Maintain an active Apple Developer Program membership.
- [ ] Create the App Store Connect app record.
- [ ] Select the correct bundle ID and create a unique SKU.
- [ ] Enter the app name (30 characters maximum).
- [ ] Write a subtitle (30 characters maximum).
- [ ] Write the App Store description.
- [ ] Choose keywords.
- [ ] Select the primary category (likely Finance).
- [ ] Complete the age-rating questionnaire.
- [ ] Enter copyright information.
- [ ] Enter the privacy-policy URL.
- [ ] Enter the support URL.
- [ ] Add App Review contact information and useful review notes.
- [ ] Select pricing and distribution territories.
- [ ] If the app is paid, complete the Paid Apps Agreement, banking, and tax information.

## Screenshots and product page

- [ ] Capture clean screenshots with realistic sample data and no personal information.
- [ ] Include the Today hero, quick expense entry, Month grid, and transparent Plan calculation.
- [ ] Upload at least one required iPhone screenshot; three to five polished screenshots are recommended.
- [x] ~~If the app supports iPad, capture and upload the required iPad screenshots.~~
      Not applicable — iPhone-only. “Designed for iPhone” on Mac needs no
      separate screenshots either.
- [ ] Verify screenshot text and UI match the submitted build.
- [ ] Decide whether to create an optional app preview video.

## Device testing and TestFlight

- [ ] Test a fresh install on a physical iPhone.
- [ ] Complete the full MVP flow:
      fresh install → enter plan → see daily number → log an expense → see the number animate → force-quit → relaunch → verify persistence.
- [ ] Confirm an expense can be logged comfortably in under three seconds.
- [ ] Test editing and deleting a transaction.
- [ ] Test several fixed expenses and every cadence.
- [ ] Test zero, very large, and cent-based currency values.
- [ ] Test a plan where expenses plus savings approach or exceed income.
- [ ] Test immediately before and after midnight.
- [ ] Test the last day and first day of a month.
- [ ] Test after changing the device time zone.
- [ ] Test after changing regional number-format settings.
      **Status:** currency is hard-coded to `code: "USD"` throughout, so a
      non-US region will see USD amounts. Decide whether that is intended for v1.
- [ ] Upload a signed Archive to App Store Connect.
- [ ] Resolve every Xcode Organizer validation error and warning.
- [ ] Distribute the build through TestFlight.
- [ ] Have at least one person other than the developer complete the fresh-install flow.

## Final submission

- [ ] Increment and confirm the marketing version and build number.
      **Status:** `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`.
- [ ] Ensure the intended source changes are committed and the release branch is clean.
      **Status:** not clean — eleven modified files and five untracked files
      (`FloatingTabBar`, `MonthDurationPicker`, `PlanSheetChrome`,
      `SegmentedControl`, `SettingsView`) are uncommitted on `main`.
- [ ] Archive the exact commit being submitted.
- [ ] Select the processed build in App Store Connect.
- [ ] Recheck metadata, screenshots, privacy answers, pricing, and territories.
- [ ] Add the version to a draft submission.
- [ ] Submit for App Review.
- [ ] Monitor App Store Connect messages and respond promptly to reviewer questions.

## Testing onboarding during development

Onboarding appears whenever the `hasCompletedOnboarding` user default is unset
or the local SwiftData store contains no `MonthPlan` records. Deleting the
installed app clears both.

### Simulator

1. Stop the app in Xcode.
2. In Simulator, return to the Home Screen.
3. Touch and hold the Left app icon.
4. Choose **Remove App**, then **Delete App**.
5. Run Left again from Xcode.
6. The full-screen **Get started** Plan screen should appear.

The equivalent Terminal command is:

```sh
xcrun simctl uninstall booted goodjobstudios.Left
```

Run the app again from Xcode after the command completes.

### Physical iPhone

1. Delete Left from the device.
2. Run it again from Xcode, or reinstall the current TestFlight build.
3. The **Get started** screen should appear.

### Important current behavior

The app still inserts a zero-value `MonthPlan` before onboarding is completed,
but that no longer suppresses onboarding: `AppRoot` re-presents the flow on any
launch where `hasCompletedOnboarding` is false, so force-quitting mid-onboarding
now resumes correctly. Deleting the app remains the way to reset to a truly
fresh state.
