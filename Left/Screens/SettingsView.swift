import SwiftUI

// Not a settings screen in the usual sense — nothing here is configurable.
// It exists because the App Store requires reachable Privacy and Support links,
// and because the one thing worth saying about this app's data is that it never
// leaves the device. Resist letting it grow into a preferences panel.
struct SettingsView: View {
    var onResetDemo: (() throws -> Void)?
    @State private var isConfirmingDemoReset = false
    @State private var demoResetError: String?

    // Both pages must resolve publicly before the first submission: App Review
    // opens them, and a dead link is a rejection.
    private enum ExternalLink {
        static let privacyPolicy = URL(string: "https://left.alexvillacres.com/privacy/")!
        static let support = URL(string: "https://left.alexvillacres.com/support/")!
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    screenTitle("Settings")

                    VStack(spacing: 0) {
                        linkRow(title: "Privacy Policy",
                                subtitle: "How Left handles your data",
                                url: ExternalLink.privacyPolicy)

                        Divider()
                            .padding(.horizontal, -AppSpacing.xl)

                        linkRow(title: "Support",
                                subtitle: "Questions and feedback",
                                url: ExternalLink.support)

#if DEBUG
                        Divider()
                            .padding(.horizontal, -AppSpacing.xl)

                        NavigationLink {
                            DataBackupView()
                        } label: {
                            ListRow(title: "Data backup",
                                    subtitle: "Export or import a JSON backup",
                                    accessory: .chevron)
                        }
                        .buttonStyle(.plain)
#endif
                    }

#if DEBUG
                    if onResetDemo != nil {
                        Button {
                            isConfirmingDemoReset = true
                        } label: {
                            Text("Reset Left Demo")
                                .font(.dmSans(.body, weight: .medium))
                                .foregroundStyle(Color.leftFeedbackNegative)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.plain)
                    }
#endif

                    dataNote
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }

            versionLabel
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.sm)
        }
        .background(Color.leftBackground.ignoresSafeArea())
#if DEBUG
        .confirmationDialog("Reset Left Demo?",
                            isPresented: $isConfirmingDemoReset,
                            titleVisibility: .visible) {
            Button("Erase demo data and start over", role: .destructive) {
                do {
                    try onResetDemo?()
                } catch {
                    demoResetError = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all plans and spending in Left Demo and opens onboarding. Your regular Left app is unaffected.")
        }
        .alert("Couldn’t reset Left Demo", isPresented: Binding(
            get: { demoResetError != nil },
            set: { if !$0 { demoResetError = nil } }
        )) {
            Button("OK") { demoResetError = nil }
        } message: {
            Text(demoResetError ?? "")
        }
#endif
    }

    // MARK: - Rows

    private func linkRow(title: String, subtitle: String, url: URL) -> some View {
        Link(destination: url) {
            // Outward arrow rather than a chevron: this leaves the app.
            ListRow(title: title, subtitle: subtitle, accessory: .external)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(title.lowercased()) in your browser")
        .accessibilityAddTraits(.isLink)
    }

    // The same claim the privacy policy makes, said once where it is actually
    // reassuring. Kept to plain sentences — no lock icons, no badges.
    private var dataNote: some View {
        Text("Your plan and spending stay on this device. Left has no accounts, no bank connections, and no analytics. Deleting the app deletes the data with it.")
            .font(.dmSans(.footnote))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacing.sm)
    }

    private var versionLabel: some View {
        Text(versionString)
            .font(.dmSansSupporting(weight: .medium))
            .foregroundStyle(Color(uiColor: .tertiaryLabel))
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Left, \(versionString)")
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    // Matches PlanView's heading treatment so the two tabs read as one app.
    private func screenTitle(_ title: String) -> some View {
        ScreenTitleRow(title: title)
    }
}

#Preview {
    SettingsView()
}
