#if DEBUG
import Foundation
import RecipiKit

/// Debug-only hooks for the app's unit and UI tests. Launching with
/// `-ui-testing` (or as the host of the unit tests) swaps the App Group and
/// CloudKit store for an in-memory one and answers every web request from
/// the fixture pages below, so tests never touch iCloud or the network.
enum TestSupport {
    static let launchArgument = "-ui-testing"
    /// Added to `-ui-testing`, starts the app with `SampleLibrary`'s
    /// recipes and grocery list, for the App Store screenshots.
    static let sampleLibraryArgument = "-sample-library"

    static var isActive: Bool {
        let process = ProcessInfo.processInfo
        return process.arguments.contains(launchArgument)
            || process.environment["XCTestConfigurationFilePath"] != nil
    }

    static var seedsSampleLibrary: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains(launchArgument) && arguments.contains(sampleLibraryArgument)
    }

    /// UI tests check amounts exactly as the fixture writes them, so they
    /// pin the units instead of following the simulator's region.
    static func pinPreferences() {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        UserDefaults.appGroup().setPreference(.asWritten, for: PreferenceKeys.measurements)
    }

    /// Routes `URLSession.shared`, which the import sheet uses, through
    /// `FixtureURLProtocol`.
    static func stubNetwork() {
        URLProtocol.registerClass(FixtureURLProtocol.self)
    }
}

/// Answers every http(s) request with a fixture page or photo, or an empty
/// 404 for anything else. Nothing goes out to the network.
final class FixtureURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let page = request.url.flatMap(FixturePages.response(for:))
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: page == nil ? 404 : 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": page?.contentType ?? "text/html; charset=utf-8"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: page?.body ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Recipe pages the tests import. The `.test` and `.example` domains are
/// reserved, so these links can never reach a real site even if the stub
/// were missing.
enum FixturePages {
    struct Response: Sendable {
        var body: Data
        var contentType: String
    }

    static let lemonSpaghettiURL = URL(string: "https://fixtures.recipi.test/lemon-spaghetti")!
    /// The page the App Store screenshots import. Its link shows in the
    /// screenshot, so it reads like a recipe site's.
    static let sheetPanGnocchiURL = URL(string: "https://cooking.example/sheet-pan-gnocchi")!
    /// Its photos, drawn by `SamplePhoto`.
    static let sheetPanGnocchiPhotoURLs = (1...3).map { URL(string: "https://cooking.example/photos/sheet-pan-gnocchi-\($0).jpg")! }

    static func response(for url: URL) -> Response? {
        if let html = html(for: url) {
            return Response(body: Data(html.utf8), contentType: "text/html; charset=utf-8")
        }
        if let index = sheetPanGnocchiPhotoURLs.firstIndex(where: { matches(url, $0) }),
           let photo = SamplePhoto.jpeg(sheetPanGnocchiPhotos[index]) {
            return Response(body: photo, contentType: "image/jpeg")
        }
        return nil
    }

    static func html(for url: URL) -> String? {
        if matches(url, lemonSpaghettiURL) { return lemonSpaghetti }
        if matches(url, sheetPanGnocchiURL) { return sheetPanGnocchi }
        return nil
    }

    private static func matches(_ url: URL, _ fixture: URL) -> Bool {
        url.host() == fixture.host() && url.path() == fixture.path()
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

    /// Serves 4, four steps, seven ingredients, three photos. Written for
    /// recipi, like `SampleLibrary`.
    static let sheetPanGnocchi = """
    <!doctype html>
    <html><head>
    <title>Sheet Pan Gnocchi with Cherry Tomatoes</title>
    <script type="application/ld+json">
    {"@context": "https://schema.org", "@type": "Recipe",
     "name": "Sheet Pan Gnocchi with Cherry Tomatoes",
     "description": "Crispy gnocchi, jammy tomatoes and one pan to wash.",
     "image": ["https://cooking.example/photos/sheet-pan-gnocchi-1.jpg",
               "https://cooking.example/photos/sheet-pan-gnocchi-2.jpg",
               "https://cooking.example/photos/sheet-pan-gnocchi-3.jpg"],
     "recipeYield": "4",
     "prepTime": "PT10M",
     "cookTime": "PT25M",
     "totalTime": "PT35M",
     "recipeCategory": "Dinner",
     "recipeCuisine": "Italian",
     "keywords": "sheet pan, vegetarian",
     "recipeIngredient": ["1 lb shelf-stable potato gnocchi", "2 cups cherry tomatoes",
                          "1 red onion, cut into wedges", "3 tbsp olive oil", "1 tsp kosher salt",
                          "4 oz fresh mozzarella, torn", "1/2 cup torn basil leaves"],
     "recipeInstructions": [
       {"@type": "HowToStep", "text": "Heat the oven to 450°F."},
       {"@type": "HowToStep", "text": "Toss the gnocchi, tomatoes and onion with the oil and salt on a large sheet pan."},
       {"@type": "HowToStep", "text": "Roast for 20 to 25 minutes, shaking the pan halfway, until the gnocchi are golden and the tomatoes burst."},
       {"@type": "HowToStep", "text": "Scatter over the mozzarella and basil and serve hot."}
     ]}
    </script>
    </head><body><h1>Sheet Pan Gnocchi with Cherry Tomatoes</h1></body></html>
    """

    /// The gnocchi page's photos: the same dish on three tables.
    static let sheetPanGnocchiPhotos: [SamplePhoto.Style] = [
        .init(
            dish: .plate, table: .init(0xD9C2A3), cloth: .init(0x6C8EAD), food: .init(0xE3B261),
            garnish: [.init(0xD8402F), .init(0x4F7A3A), .init(0xF6F1E7)], seed: 101
        ),
        .init(
            dish: .plate, table: .init(0x59616B), cloth: .init(0xC8553D), food: .init(0xE3B261),
            garnish: [.init(0xD8402F), .init(0x4F7A3A), .init(0xF6F1E7)], seed: 102
        ),
        .init(
            dish: .bowl, table: .init(0xEDE6DA), cloth: .init(0x8AA27A), food: .init(0xE3B261),
            garnish: [.init(0xD8402F), .init(0x4F7A3A), .init(0xF6F1E7)], seed: 103
        ),
    ]
}
#endif
