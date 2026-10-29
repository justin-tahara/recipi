import Foundation
import SwiftData

/// Builds the one SwiftData container that the app and the share extension
/// both open. It lives in the shared App Group so a recipe saved from Safari
/// shows up in the app, and it syncs through the person's private CloudKit
/// database unless they turned iCloud sync off in Settings. There is no
/// server.
public enum RecipiStore {
    public static var schema: Schema {
        Schema([
            Recipe.self,
            Ingredient.self,
            Step.self,
            Tag.self,
            GroceryItem.self,
            CookLog.self,
        ])
    }

    public static func makeContainer(
        configuration: AppConfiguration = .current,
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Self.schema
        let modelConfiguration: ModelConfiguration
        if inMemory {
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let groupContainer: ModelConfiguration.GroupContainer
            if let appGroupID = configuration.appGroupID {
                groupContainer = .identifier(appGroupID)
            } else {
                groupContainer = .automatic
            }
            // SwiftData can't turn CloudKit on or off for a container that's
            // already open, so the preference is read here and a change
            // applies the next time the app or the extension starts.
            let iCloudSyncEnabled = UserDefaults.appGroup(configuration).preference(PreferenceKeys.iCloudSync)
            let cloudKitDatabase: ModelConfiguration.CloudKitDatabase
            switch cloudSync(for: configuration, iCloudSyncEnabled: iCloudSyncEnabled) {
            case .off:
                cloudKitDatabase = .none
            case .privateDatabase(let containerID):
                cloudKitDatabase = .private(containerID)
            }
            modelConfiguration = ModelConfiguration(
                schema: schema,
                groupContainer: groupContainer,
                cloudKitDatabase: cloudKitDatabase
            )
        }
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    /// Whether the store syncs, and where.
    public enum CloudSync: Equatable, Sendable {
        /// Recipes stay on this device.
        case off
        /// Recipes sync through the person's private CloudKit database.
        case privateDatabase(containerID: String)
    }

    /// Syncs only when the person has iCloud sync on and the build has an
    /// iCloud container (forks and unsigned builds may not).
    public static func cloudSync(for configuration: AppConfiguration, iCloudSyncEnabled: Bool) -> CloudSync {
        guard iCloudSyncEnabled, let containerID = configuration.cloudKitContainerID else {
            return .off
        }
        return .privateDatabase(containerID: containerID)
    }
}

/// Identifiers that come from build settings (Config/Base.xcconfig) through
/// each target's Info.plist, so forks can change them in one place.
public struct AppConfiguration: Sendable {
    public var appGroupID: String?
    public var cloudKitContainerID: String?

    public init(appGroupID: String?, cloudKitContainerID: String?) {
        self.appGroupID = appGroupID
        self.cloudKitContainerID = cloudKitContainerID
    }

    public static var current: AppConfiguration {
        AppConfiguration(
            appGroupID: Bundle.main.nonEmptyString(forInfoKey: "RecipiAppGroupID"),
            cloudKitContainerID: Bundle.main.nonEmptyString(forInfoKey: "RecipiCloudKitContainerID")
        )
    }
}

extension Bundle {
    fileprivate func nonEmptyString(forInfoKey key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) as? String, !value.isEmpty, !value.hasPrefix("$(") else {
            return nil
        }
        return value
    }
}
