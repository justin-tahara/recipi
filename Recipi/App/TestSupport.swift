#if DEBUG
import Foundation

/// Debug-only hooks for the app's unit and UI tests. Launching with
/// `-ui-testing` (or as the host of the unit tests) swaps the App Group and
/// CloudKit store for an in-memory one and answers every web request from
/// the fixture pages below, so tests never touch iCloud or the network.
enum TestSupport {
    static let launchArgument = "-ui-testing"

    static var isActive: Bool {
        let process = ProcessInfo.processInfo
        return process.arguments.contains(launchArgument)
            || process.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Routes `URLSession.shared`, which the import sheet uses, through
    /// `FixtureURLProtocol`.
    static func stubNetwork() {
        URLProtocol.registerClass(FixtureURLProtocol.self)
    }
}

/// Answers every http(s) request with a fixture page, or an empty 404 for
/// anything else. Nothing goes out to the network.
final class FixtureURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: FixturePages.html(for: url) == nil ? 404 : 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data((FixturePages.html(for: url) ?? "").utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Recipe pages the tests import. The `.test` domain is reserved, so these
/// links can never reach a real site even if the stub were missing.
enum FixturePages {
    static let lemonSpaghettiURL = URL(string: "https://fixtures.recipi.test/lemon-spaghetti")!

    static func html(for url: URL) -> String? {
        guard url.host() == lemonSpaghettiURL.host(), url.path() == lemonSpaghettiURL.path() else {
            return nil
        }
        return lemonSpaghetti
    }

    /// Serves 4, two steps, four ingredients, no photo.
    static let lemonSpaghetti = """
    <!doctype html>
    <html><head>
    <title>Lemon Garlic Spaghetti</title>
    <script type="application/ld+json">
    {"@context": "https://schema.org", "@type": "Recipe",
     "name": "Lemon Garlic Spaghetti",
     "description": "A quick weeknight pasta.",
     "author": {"@type": "Person", "name": "Recipi Tests"},
     "recipeYield": "4",
     "totalTime": "PT20M",
     "recipeCategory": "Dinner",
     "keywords": "pasta, quick",
     "recipeIngredient": ["400 g spaghetti", "2 lemons", "4 cloves garlic", "60 g parmesan"],
     "recipeInstructions": [
       {"@type": "HowToStep", "text": "Boil the spaghetti in salted water until al dente."},
       {"@type": "HowToStep", "text": "Toss with the lemon, garlic and parmesan, then serve."}
     ]}
    </script>
    </head><body><h1>Lemon Garlic Spaghetti</h1></body></html>
    """
}
#endif
