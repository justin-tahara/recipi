import Foundation
import SwiftData

/// Builds the one SwiftData container that the app and the share extension
/// both open. It lives in the shared App Group so a recipe saved from Safari
/// shows up in the app, and it syncs through the person's private CloudKit
/// database. There is no server.
public enum RecipiStore {
    public static var schema: Schema {
        Schema([
            Recipe.self,
            Ingredient.self,
            Step.self,
            Tag.self,
            GroceryItem.self,
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
            let cloudKitDatabase: ModelConfiguration.CloudKitDatabase
            if let containerID = configuration.cloudKitContainerID {
                cloudKitDatabase = .private(containerID)
            } else {
                cloudKitDatabase = .none
            }
            modelConfiguration = ModelConfiguration(
                schema: schema,
                groupContainer: groupContainer,
                cloudKitDatabase: cloudKitDatabase
            )
        }
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
