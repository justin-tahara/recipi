import Foundation
import Observation

/// App-wide preferences for screens. Reads and writes go straight to the App
/// Group's `UserDefaults`, so the share extension sees the same values, and
/// SwiftUI views that read a preference update when it changes.
///
/// `UserDefaults` isn't `Sendable`, so this model stays on the main actor.
/// Code that runs elsewhere, like opening the store, reads a value with
/// `UserDefaults.appGroup().preference(_:)` instead.
@MainActor
@Observable
public final class Preferences {
    private let defaults: UserDefaults
    /// Bumped on every write. Each read touches it, so a view that reads any
    /// preference is redrawn when one changes.
    private var revision = 0

    /// Pass your own `UserDefaults` in tests and previews.
    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public convenience init(configuration: AppConfiguration = .current) {
        self.init(defaults: .appGroup(configuration))
    }

    public subscript<Value>(key: PreferenceKey<Value>) -> Value {
        get {
            _ = revision
            return defaults.preference(key)
        }
        set {
            defaults.setPreference(newValue, for: key)
            revision += 1
        }
    }

    public func reset<Value>(_ key: PreferenceKey<Value>) {
        defaults.resetPreference(key)
        revision += 1
    }

    /// See `PreferenceKeys.iCloudSync`. Applies on the next launch.
    public var iCloudSyncEnabled: Bool {
        get { self[PreferenceKeys.iCloudSync] }
        set { self[PreferenceKeys.iCloudSync] = newValue }
    }

    /// See `PreferenceKeys.librarySort`.
    public var librarySort: LibrarySort {
        get { self[PreferenceKeys.librarySort] }
        set { self[PreferenceKeys.librarySort] = newValue }
    }

    /// See `PreferenceKeys.measurements`.
    public var measurements: MeasurementPreference {
        get { self[PreferenceKeys.measurements] }
        set { self[PreferenceKeys.measurements] = newValue }
    }
}
