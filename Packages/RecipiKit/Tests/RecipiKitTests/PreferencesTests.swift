import Foundation
import Testing
@testable import RecipiKit

/// Each test gets its own throwaway suite, so tests can run in parallel and
/// nothing leaks into the real defaults.
private func withScratchDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
    let suiteName = "RecipiKitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    try body(defaults)
}

private enum Flavor: String, PreferenceValue {
    case sweet, savory
}

struct PreferenceKeyTests {
    @Test func iCloudSyncIsOnByDefault() {
        withScratchDefaults { defaults in
            #expect(defaults.preference(PreferenceKeys.iCloudSync) == true)
        }
    }

    @Test func measurementsFollowTheDeviceUntilChanged() {
        withScratchDefaults { defaults in
            #expect(defaults.preference(PreferenceKeys.measurements) == MeasurementPreference.deviceDefault())
            defaults.setPreference(.asWritten, for: PreferenceKeys.measurements)
            #expect(defaults.preference(PreferenceKeys.measurements) == .asWritten)
        }
    }

    @Test func boolRoundTrips() {
        withScratchDefaults { defaults in
            defaults.setPreference(false, for: PreferenceKeys.iCloudSync)
            #expect(defaults.preference(PreferenceKeys.iCloudSync) == false)
            defaults.setPreference(true, for: PreferenceKeys.iCloudSync)
            #expect(defaults.preference(PreferenceKeys.iCloudSync) == true)
        }
    }

    @Test func otherTypesRoundTrip() {
        withScratchDefaults { defaults in
            let count = PreferenceKey<Int>("test.count", default: 2)
            let ratio = PreferenceKey<Double>("test.ratio", default: 1.5)
            let name = PreferenceKey<String>("test.name", default: "")
            let flavor = PreferenceKey<Flavor>("test.flavor", default: .sweet)

            #expect(defaults.preference(count) == 2)
            #expect(defaults.preference(ratio) == 1.5)
            #expect(defaults.preference(name) == "")
            #expect(defaults.preference(flavor) == .sweet)

            defaults.setPreference(7, for: count)
            defaults.setPreference(0.25, for: ratio)
            defaults.setPreference("pancakes", for: name)
            defaults.setPreference(.savory, for: flavor)

            #expect(defaults.preference(count) == 7)
            #expect(defaults.preference(ratio) == 0.25)
            #expect(defaults.preference(name) == "pancakes")
            #expect(defaults.preference(flavor) == .savory)
            #expect(defaults.string(forKey: "test.flavor") == "savory")
        }
    }

    @Test func wrongStoredTypeReadsAsDefault() {
        withScratchDefaults { defaults in
            defaults.set("yes", forKey: PreferenceKeys.iCloudSync.name)
            #expect(defaults.preference(PreferenceKeys.iCloudSync) == true)

            let flavor = PreferenceKey<Flavor>("test.flavor", default: .sweet)
            defaults.set("bitter", forKey: flavor.name)
            #expect(defaults.preference(flavor) == .sweet)
        }
    }

    @Test func resetGoesBackToDefault() {
        withScratchDefaults { defaults in
            defaults.setPreference(false, for: PreferenceKeys.iCloudSync)
            defaults.resetPreference(PreferenceKeys.iCloudSync)
            #expect(defaults.preference(PreferenceKeys.iCloudSync) == true)
        }
    }

    @Test func noAppGroupFallsBackToStandard() {
        let configuration = AppConfiguration(appGroupID: nil, cloudKitContainerID: nil)
        #expect(UserDefaults.appGroup(configuration) === UserDefaults.standard)
    }
}

@MainActor
struct PreferencesModelTests {
    @Test func readsDefaultsAndWritesThrough() {
        withScratchDefaults { defaults in
            let preferences = Preferences(defaults: defaults)
            #expect(preferences.iCloudSyncEnabled == true)

            preferences.iCloudSyncEnabled = false
            #expect(preferences.iCloudSyncEnabled == false)
            #expect(defaults.preference(PreferenceKeys.iCloudSync) == false)

            // A second reader of the same suite, like the share extension,
            // sees the change.
            #expect(Preferences(defaults: defaults).iCloudSyncEnabled == false)
        }
    }

    @Test func resetGoesBackToDefault() {
        withScratchDefaults { defaults in
            let preferences = Preferences(defaults: defaults)
            preferences.iCloudSyncEnabled = false
            preferences.reset(PreferenceKeys.iCloudSync)
            #expect(preferences.iCloudSyncEnabled == true)
        }
    }
}

struct CloudSyncChoiceTests {
    private let configuration = AppConfiguration(appGroupID: "group.test", cloudKitContainerID: "iCloud.test")

    @Test func syncsToPrivateDatabaseWhenOn() {
        #expect(RecipiStore.cloudSync(for: configuration, iCloudSyncEnabled: true) == .privateDatabase(containerID: "iCloud.test"))
    }

    @Test func staysLocalWhenOff() {
        #expect(RecipiStore.cloudSync(for: configuration, iCloudSyncEnabled: false) == .off)
    }

    @Test func staysLocalWithoutAContainer() {
        let noContainer = AppConfiguration(appGroupID: nil, cloudKitContainerID: nil)
        #expect(RecipiStore.cloudSync(for: noContainer, iCloudSyncEnabled: true) == .off)
    }
}
