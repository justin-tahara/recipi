import Foundation
import Testing
@testable import RecipiKit

/// The importer's fetching: redirects, meta refreshes, AMP pages and page
/// encodings. Responses come from `FixtureURLProtocol`, never the network.
struct RecipeImporterTests {
    @Test func followsHTTPRedirects() async throws {
        let short = URL(string: "https://redirect.fixture.test/r/abc")!
        let page = URL(string: "https://redirect.fixture.test/recipes/soup/")!
        let session = FixtureURLProtocol.session([
            short: .redirect(to: page),
            page: .html(try Fixture.html("yield-range-string-image")),
        ])
        let draft = try await RecipeImporter(session: session, rendersJavaScript: false).importRecipe(from: short)
        #expect(draft.title == "Roasted Tomato Soup")
        #expect(draft.sourceURL == page)
        #expect(draft.imageURL == URL(string: "https://redirect.fixture.test/media/roasted-tomato-soup.jpg"))
    }

    @Test func followsAMetaRefresh() async throws {
        let short = URL(string: "https://refresh.fixture.test/s/xyz")!
        let page = URL(string: "https://refresh.fixture.test/garlic-butter-shrimp/")!
        let refresh = try Fixture.html("meta-refresh")
            .replacingOccurrences(of: "https://example.com/", with: "https://refresh.fixture.test/")
        let session = FixtureURLProtocol.session([
            short: .html(refresh),
            page: .html(try Fixture.html("lang-it")),
        ])
        let draft = try await RecipeImporter(session: session, rendersJavaScript: false).importRecipe(from: short)
        #expect(draft.title == "Spaghetti alla carbonara")
        #expect(draft.sourceURL == page)
    }

    @Test func usesTheCanonicalPageOfAnAMPPageWithoutRecipeData() async throws {
        let amp = URL(string: "https://amp.fixture.test/garlic-butter-shrimp/amp/")!
        let canonical = URL(string: "https://amp.fixture.test/garlic-butter-shrimp/")!
        let ampPage = try Fixture.html("amp-canonical")
            .replacingOccurrences(of: "https://example.com/", with: "https://amp.fixture.test/")
        let session = FixtureURLProtocol.session([
            amp: .html(ampPage),
            canonical: .html(try Fixture.html("tasty-recipes")),
        ])
        let draft = try await RecipeImporter(session: session, rendersJavaScript: false).importRecipe(from: amp)
        #expect(draft.title == "Brown Butter Chocolate Chip Cookies")
        #expect(draft.sourceURL == canonical)
    }

    @Test func givesUpOnAJavaScriptOnlyPageWhenNotRendering() async throws {
        let page = URL(string: "https://js.fixture.test/recipes/noodles/")!
        let session = FixtureURLProtocol.session([page: .html(try Fixture.html("js-rendered-only"))])
        await #expect(throws: RecipeImportError.noRecipeFound) {
            try await RecipeImporter(session: session, rendersJavaScript: false).importRecipe(from: page)
        }
    }

    @Test func doesNotLoopOnPagesThatPointAtEachOther() async throws {
        let first = URL(string: "https://loop.fixture.test/a")!
        let second = URL(string: "https://loop.fixture.test/b")!
        func refresh(to url: URL) -> String {
            #"<html><head><meta http-equiv="refresh" content="0;url=\#(url.absoluteString)"></head></html>"#
        }
        let session = FixtureURLProtocol.session([first: .html(refresh(to: second)), second: .html(refresh(to: first))])
        await #expect(throws: RecipeImportError.noRecipeFound) {
            try await RecipeImporter(session: session, rendersJavaScript: false).importRecipe(from: first)
        }
    }

    @Test func findsFollowUpLinks() throws {
        let ampURL = URL(string: "https://example.com/garlic-butter-shrimp/amp/")!
        #expect(RecipeImporter.followUpURL(in: try Fixture.html("amp-canonical"), pageURL: ampURL)
            == URL(string: "https://example.com/garlic-butter-shrimp/"))
        #expect(RecipeImporter.followUpURL(in: try Fixture.html("meta-refresh"), pageURL: URL(string: "https://sho.rt/x")!)
            == URL(string: "https://example.com/garlic-butter-shrimp/"))
        // A canonical link on an ordinary page is not followed.
        #expect(RecipeImporter.followUpURL(in: try Fixture.html("yoast-graph"), pageURL: Fixture.pageURL("yoast-graph")) == nil)
    }

    @Test func recognisesAMPPages() {
        let page = URL(string: "https://example.com/post/")!
        #expect(RecipeImporter.isAMP(#"<html amp lang="en">"#, url: page))
        #expect(RecipeImporter.isAMP("<html ⚡>", url: page))
        #expect(RecipeImporter.isAMP("<html>", url: URL(string: "https://example.com/post/amp/")!))
        #expect(!RecipeImporter.isAMP(#"<html lang="en" class="example">"#, url: page))
    }

    @Test func decodesPagesInTheirDeclaredCharset() throws {
        let html = #"<html><head><meta charset="shift_jis"><title>親子丼</title></head></html>"#
        let data = try #require(html.data(using: .shiftJIS))
        #expect(RecipeImporter.decodePage(data, encodingName: nil) == html)
        #expect(RecipeImporter.decodePage(data, encodingName: "Shift_JIS") == html)
        let latin = try #require("Crème brûlée".data(using: .isoLatin1))
        #expect(RecipeImporter.decodePage(latin, encodingName: "iso-8859-1") == "Crème brûlée")
    }
}

struct SharedLinkTests {
    @Test(arguments: [
        ("https://example.com/pie", "https://example.com/pie"),
        ("  https://example.com/pie?ref=share  \n", "https://example.com/pie?ref=share"),
        ("Grandma's Apple Pie – Example Bakes\nhttps://example.com/apple-pie/", "https://example.com/apple-pie/"),
        ("Look at this one: https://example.com/a and also https://example.org/b", "https://example.com/a"),
        ("mail me at cook@example.com or see http://example.com/stew", "http://example.com/stew"),
        ("https://example.com/stew so good", "https://example.com/stew"),
    ])
    func findsTheFirstWebLink(text: String, expected: String) {
        #expect(SharedLink.firstWebURL(in: text)?.absoluteString == expected)
    }

    @Test(arguments: ["", "no link in here", "ftp://example.com/file", "https://"])
    func findsNothingWithoutAWebLink(text: String) {
        #expect(SharedLink.firstWebURL(in: text) == nil)
    }
}

struct RecipeValuesTests {
    @Test(arguments: [
        ("4", 4), ("Serves 4-6", 4), ("4 Portionen", 4), ("2人分", 2), ("２人分", 2), ("Makes 24 cookies", 24),
    ])
    func readsServings(yield: String, expected: Int) {
        #expect(RecipeValues.servings(in: yield) == expected)
    }

    @Test(arguments: ["A big bowl", "", "0", "二人分"])
    func readsNoServings(yield: String) {
        #expect(RecipeValues.servings(in: yield) == nil)
    }

    @Test(arguments: [
        ("PT20M", 1_200.0), ("1 hour 30 minutes", 5_400.0), ("45 Min.", 2_700.0), ("1 hr 15 mins", 4_500.0),
        ("1時間30分", 5_400.0), ("2 Stunden", 7_200.0), ("1 heure 10 min", 4_200.0),
    ])
    func readsDurations(text: String, expected: Double) {
        #expect(RecipeValues.duration(from: text) == expected)
    }

    @Test(arguments: ["PT0M", "PT0H0M", "P0D", "soon", "15"])
    func treatsZeroAndUnreadableTimesAsUnknown(text: String) {
        #expect(RecipeValues.duration(from: text) == nil)
    }

    @Test func prefersTheFullerYieldForTheSameCount() {
        #expect(RecipeValues.yieldText(from: ["4", "4 servings"]) == "4 servings")
        #expect(RecipeValues.yieldText(from: ["6", "1 large pot"]) == "6")
        #expect(RecipeValues.yieldText(from: []) == nil)
    }
}
