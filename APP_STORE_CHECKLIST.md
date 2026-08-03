# Left — App Store Launch Checklist

## Release blockers

- [ ] Add a 1024×1024 primary app icon to `Assets.xcassets/AppIcon.appiconset`.
- [ ] Add dark and tinted app icon variants, if desired.
- [ ] Change the deployment target from iOS/iPadOS 26.5 to the intended minimum (the product brief specifies iOS 17).
- [ ] Confirm the Release configuration builds successfully after lowering the deployment target.
- [ ] Confirm the final bundle identifier (`goodjobstudios.Left`) before the first upload.
- [ ] Confirm the app name “Left” is available in App Store Connect.

## Onboarding and plan validation

- [x] Keep presenting onboarding until setup has actually been completed.
- [x] Disable onboarding progression until monthly income is greater than zero.
- [x] Require monthly spendable income to be greater than zero:
      `income − fixed expenses − savings goal > 0`.
- [ ] Test quitting during onboarding and relaunching.
- [ ] Test completing onboarding and relaunching.
- [ ] Verify the completed plan persists after force-quitting.

## Core product readiness

- [ ] Add the always-visible Plan derivation:
      `income − fixed expenses − savings = spendable ÷ days = daily rate`.
- [ ] Apply the intended positive, warning, and negative colors to the Today hero amount.
- [ ] Add or deliberately remove the month-progress footer and net-position summary from the product scope.
- [ ] Verify that transaction swipe-to-delete does not also trigger day navigation.
- [ ] Decide whether deleted transactions and fixed expenses need confirmation or Undo.
- [ ] Verify month-boundary plan creation on launch and when returning to the foreground.
- [ ] Verify rollover calculations across the last and first days of a month.
- [ ] Decide how the app should recover if its local SwiftData store cannot be opened.

## Supported devices and accessibility

- [ ] Decide whether v1 is iPhone-only or supports both iPhone and iPad.
- [ ] Decide whether v1 supports landscape or portrait only.
- [ ] If iPad is supported, test every screen on small and large iPads.
- [ ] If landscape is supported, test every screen and sheet in landscape.
- [ ] Test Light Mode and Dark Mode.
- [ ] Test the largest Dynamic Type accessibility sizes.
- [ ] Test VoiceOver navigation and spoken currency values.
- [ ] Make calendar outcomes understandable without relying only on color.
- [ ] Verify every interactive control has at least a 44×44-point hit area.
- [ ] Test Reduce Motion and confirm numeric updates remain understandable.

## Privacy, support, and legal

- [ ] Publish a public privacy-policy webpage.
- [ ] Explain that budget and transaction data stays on the device.
- [ ] Explain retention and deletion behavior, including that deleting the app removes local data.
- [ ] Add an easily accessible Privacy Policy link inside the app.
- [ ] Publish a support webpage or support contact page.
- [ ] Add an easily accessible Support link inside the app.
- [ ] Confirm App Privacy answers in App Store Connect. With the current local-only architecture and no analytics, “Data Not Collected” is likely appropriate.
- [ ] Confirm rights and licenses for all bundled fonts and other assets.
- [ ] Complete export-compliance questions. The app currently appears to use no custom encryption.
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
- [ ] If the app supports iPad, capture and upload the required iPad screenshots.
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
- [ ] Upload a signed Archive to App Store Connect.
- [ ] Resolve every Xcode Organizer validation error and warning.
- [ ] Distribute the build through TestFlight.
- [ ] Have at least one person other than the developer complete the fresh-install flow.

## Final submission

- [ ] Increment and confirm the marketing version and build number.
- [ ] Ensure the intended source changes are committed and the release branch is clean.
- [ ] Archive the exact commit being submitted.
- [ ] Select the processed build in App Store Connect.
- [ ] Recheck metadata, screenshots, privacy answers, pricing, and territories.
- [ ] Add the version to a draft submission.
- [ ] Submit for App Review.
- [ ] Monitor App Store Connect messages and respond promptly to reviewer questions.

## Testing onboarding during development

Onboarding appears only when the app's local SwiftData store contains no
`MonthPlan` records. Deleting the installed app clears that store.

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

The app inserts a zero-value `MonthPlan` before onboarding is completed.
Consequently, dismissing onboarding or force-quitting during it can prevent
onboarding from appearing on the next launch. Until that behavior is fixed,
delete the app again whenever a completely fresh onboarding test is needed.
