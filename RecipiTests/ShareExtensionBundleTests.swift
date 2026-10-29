import Foundation
import Testing

/// Safari only hands the share extension the loaded page when the
/// extension's Info.plist names a preprocessing script that's in its bundle.
struct ShareExtensionBundleTests {
    private var extensionBundle: Bundle? {
        Bundle.main.builtInPlugInsURL
            .map { $0.appending(path: "RecipiShare.appex") }
            .flatMap(Bundle.init(url:))
    }

    @Test func shipsSafarisPreprocessingScript() throws {
        let bundle = try #require(extensionBundle)
        let attributes = try #require(
            (bundle.object(forInfoDictionaryKey: "NSExtension") as? [String: Any])?["NSExtensionAttributes"] as? [String: Any]
        )
        let script = try #require(attributes["NSExtensionJavaScriptPreprocessingFile"] as? String)
        #expect(script == "SafariPage")
        #expect(bundle.url(forResource: script, withExtension: "js") != nil)

        let rule = try #require(attributes["NSExtensionActivationRule"] as? [String: Any])
        #expect(rule["NSExtensionActivationSupportsWebPageWithMaxCount"] as? Int == 1)
    }
}
