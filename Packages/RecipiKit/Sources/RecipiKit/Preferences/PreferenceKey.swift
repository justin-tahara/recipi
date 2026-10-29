import Foundation

/// A named preference with the value it has until the person changes it.
/// Every preference recipi stores is declared once in `PreferenceKeys`, so
/// features don't each invent their own `UserDefaults` keys.
public struct PreferenceKey<Value: PreferenceValue>: Sendable {
    /// The `UserDefaults` key. It's written to people's devices, so never
    /// rename it once a release has shipped.
    public let name: String
    public let defaultValue: Value

    public init(_ name: String, default defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

/// Every app-wide preference. Add new ones here.
public enum PreferenceKeys {
    /// Sync recipes through the person's private iCloud database. On by
    /// default. The store reads this when it opens, so a change applies the
    /// next time the app (or the share extension) starts.
    public static let iCloudSync = PreferenceKey<Bool>("sync.iCloudEnabled", default: true)
}

/// A type that can be stored in `UserDefaults`. Bool, Int, Double and String
/// are built in. A `String` or `Int` backed enum only has to declare the
/// conformance; it's stored as its raw value.
public protocol PreferenceValue: Sendable {
    /// The stored value, or nil when there's none or it has the wrong type.
    static func read(from defaults: UserDefaults, forKey key: String) -> Self?
    func write(to defaults: UserDefaults, forKey key: String)
}

extension PreferenceValue where Self: RawRepresentable, RawValue: PreferenceValue {
    public static func read(from defaults: UserDefaults, forKey key: String) -> Self? {
        RawValue.read(from: defaults, forKey: key).flatMap(Self.init(rawValue:))
    }

    public func write(to defaults: UserDefaults, forKey key: String) {
        rawValue.write(to: defaults, forKey: key)
    }
}

extension Bool: PreferenceValue {
    public static func read(from defaults: UserDefaults, forKey key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    public func write(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension Int: PreferenceValue {
    public static func read(from defaults: UserDefaults, forKey key: String) -> Int? {
        defaults.object(forKey: key) as? Int
    }

    public func write(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension Double: PreferenceValue {
    public static func read(from defaults: UserDefaults, forKey key: String) -> Double? {
        defaults.object(forKey: key) as? Double
    }

    public func write(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension String: PreferenceValue {
    public static func read(from defaults: UserDefaults, forKey key: String) -> String? {
        // Not `string(forKey:)`, which would turn a stored number into text.
        defaults.object(forKey: key) as? String
    }

    public func write(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension UserDefaults {
    /// The defaults the app and the share extension share, in the App Group,
    /// so both read the same preferences. Falls back to `.standard` when the
    /// build has no App Group, as in tests.
    ///
    /// This doesn't touch the main actor, so it's safe to call while opening
    /// the store. Screens use `Preferences` instead.
    public static func appGroup(_ configuration: AppConfiguration = .current) -> UserDefaults {
        if let appGroupID = configuration.appGroupID, let defaults = UserDefaults(suiteName: appGroupID) {
            return defaults
        }
        return .standard
    }

    /// The stored value for `key`, or its default when nothing (or something
    /// of the wrong type) is stored.
    public func preference<Value>(_ key: PreferenceKey<Value>) -> Value {
        Value.read(from: self, forKey: key.name) ?? key.defaultValue
    }

    public func setPreference<Value>(_ value: Value, for key: PreferenceKey<Value>) {
        value.write(to: self, forKey: key.name)
    }

    /// Forgets the stored value, so `key` reads as its default again.
    public func resetPreference<Value>(_ key: PreferenceKey<Value>) {
        removeObject(forKey: key.name)
    }
}
