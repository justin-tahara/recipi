import Foundation
import Testing

/// The privacy manifests and the export compliance key are only read by
/// Apple at upload time, so check here that they made it into the build.
struct PrivacyManifestTests {
    @Test(arguments: ["app", "share extension"])
    func manifestShipsAndDeclaresNoTracking(target: String) throws {
        let bundleURL = target == "app"
            ? Bundle.main.bundleURL
            : try #require(Bundle.main.builtInPlugInsURL).appending(path: "RecipiShare.appex")
        let manifestURL = bundleURL.appending(path: "PrivacyInfo.xcprivacy")
        let data = try Data(contentsOf: manifestURL)
        let manifest = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        let apis = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = try #require(apis.first {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        })
        #expect(userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1", "1C8F.1"])
    }

    @Test func appDeclaresNoNonExemptEncryption() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool == false)
    }
}
