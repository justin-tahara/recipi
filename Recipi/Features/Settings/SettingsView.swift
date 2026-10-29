import RecipiDesign
import RecipiKit
import SwiftUI

/// App-wide preferences, opened from the gear in the Library. More sections
/// (language) arrive with their own features.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var preferences = Preferences()
    /// The sync setting when this sheet opened, to tell whether the person
    /// changed it and still needs to reopen the app.
    @State private var syncWhenOpened: Bool?

    private let configuration = AppConfiguration.current

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    measurementsSection
                    syncSection
                    // Its own view, in BackupSection.swift.
                    BackupSection()
                    aboutSection
                }
                .listRowBackground(Theme.Colors.elevated)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.surface)
            .motion(Motion.snappy, value: needsRelaunch)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if syncWhenOpened == nil {
                    syncWhenOpened = preferences.iCloudSyncEnabled
                }
            }
        }
        .tint(Theme.Colors.accent)
    }

    // MARK: Measurements

    private var measurementsSection: some View {
        Section {
            Picker(selection: $preferences.measurements) {
                ForEach(MeasurementPreference.allCases) { option in
                    Text(option.title).tag(option)
                }
            } label: {
                Label("Units", systemImage: "ruler")
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        } header: {
            Text("Measurements")
        } footer: {
            Text("Shows amounts and oven temperatures in the units you're used to. Only like for like: cups become milliliters and ounces become grams, never cups into grams. You can switch a single recipe from its page.")
        }
    }

    // MARK: iCloud sync

    private var syncSection: some View {
        Section {
            // A build without an iCloud container can't sync, so the switch
            // shows off rather than a setting that does nothing.
            Toggle(isOn: hasICloudContainer ? $preferences.iCloudSyncEnabled : .constant(false)) {
                Label("iCloud sync", systemImage: "icloud")
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .disabled(!hasICloudContainer)

            if needsRelaunch {
                Callout(symbol: "arrow.clockwise", color: .blue) {
                    Text(preferences.iCloudSyncEnabled
                        ? "Close recipi and open it again to start syncing."
                        : "Close recipi and open it again to stop syncing.")
                        .font(Theme.Fonts.meta)
                }
                .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.xs, bottom: Theme.Spacing.xs, trailing: Theme.Spacing.xs))
                .transition(.opacity)
            }
        } header: {
            Text("Sync")
        } footer: {
            Text(syncFooter)
        }
    }

    private var syncFooter: String {
        if !hasICloudContainer {
            return "This build of recipi has no iCloud container, so your recipes stay on this device."
        }
        return "Keeps your recipes in step across your devices through your own iCloud account. "
            + "A change takes effect the next time you open recipi. Turning sync off keeps your recipes on this device."
    }

    private var hasICloudContainer: Bool {
        configuration.cloudKitContainerID != nil
    }

    private var needsRelaunch: Bool {
        guard let syncWhenOpened else { return false }
        return hasICloudContainer && syncWhenOpened != preferences.iCloudSyncEnabled
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: AppInfo.version)
            LabeledContent("Build", value: AppInfo.build)

            Link(destination: AppInfo.repositoryURL) {
                linkLabel("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .accessibilityHint("Opens in your browser")

            Link(destination: AppInfo.licenseURL) {
                linkLabel("MIT License", systemImage: "doc.text")
            }
            .accessibilityHint("Opens in your browser")

            Label {
                Text("Your recipes stay on your device and in your own iCloud. There's no account, and recipi collects no data.")
                    .font(Theme.Fonts.meta)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } icon: {
                Image(systemName: "hand.raised")
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text("About")
        }
    }

    private func linkLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer(minLength: Theme.Spacing.xs)
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
                .accessibilityHidden(true)
        }
    }
}

/// What the About section shows, read from the app's Info.plist.
private enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    // Constant strings, so these never fail.
    static let repositoryURL = URL(string: "https://github.com/justin-tahara/recipi")!
    static let licenseURL = URL(string: "https://github.com/justin-tahara/recipi/blob/main/LICENSE")!
}
