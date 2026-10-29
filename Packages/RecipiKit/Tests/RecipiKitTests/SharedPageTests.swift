import Foundation
import Testing
@testable import RecipiKit

/// The page Safari hands the share extension, and reading a recipe from it
/// without fetching anything.
struct SharedPageTests {
    @Test func readsSafarisPreprocessingResults() throws {
        let page = try #require(SharedPage(preprocessingResults: [
            "url": "https://example.com/pancakes/",
            "html": "<html><body>Pancakes</body></html>",
        ]))
        #expect(page.url == URL(string: "https://example.com/pancakes/"))
        #expect(page.html == "<html><body>Pancakes</body></html>")
    }

    @Test(arguments: [
        (nil, nil),
        ("https://example.com/pancakes/", nil),
        (nil, "<html></html>"),
        ("https://example.com/pancakes/", ""),
        ("file:///etc/hosts", "<html></html>"),
        ("not a link", "<html></html>"),
    ] as [(String?, String?)])
    func ignoresIncompleteResults(url: String?, html: String?) {
        var results: [AnyHashable: Any] = [:]
        results["url"] = url
        results["html"] = html
        #expect(SharedPage(preprocessingResults: results) == nil)
    }

    @Test func ignoresValuesOfTheWrongType() {
        #expect(SharedPage(preprocessingResults: ["url": 42, "html": "<html></html>"]) == nil)
    }

    @Test func readsTheRecipeFromTheLoadedPage() throws {
        let page = SharedPage(
            url: URL(string: "https://example.com/recipes/yoast-graph/?utm_source=share&ref=menu")!,
            html: try Fixture.html("yoast-graph")
        )
        let draft = try RecipeImporter.recipe(in: page)
        #expect(draft.title == "Lemon Ricotta Pancakes")
        #expect(draft.ingredients.count == 8)
        // Saved without tracking parameters, like any import.
        #expect(draft.sourceURL == URL(string: "https://example.com/recipes/yoast-graph/?ref=menu"))
    }

    @Test func aLoadedPageWithoutARecipeSaysSo() {
        let page = SharedPage(url: URL(string: "https://example.com/about/")!, html: "<html><body>About us</body></html>")
        #expect(throws: RecipeImportError.noRecipeFound) {
            try RecipeImporter.recipe(in: page)
        }
    }
}
