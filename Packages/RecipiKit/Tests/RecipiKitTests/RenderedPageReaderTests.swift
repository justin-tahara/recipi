#if canImport(WebKit)
import Foundation
import Testing
@testable import RecipiKit

/// The offscreen web view fallback, on a page whose JSON-LD only exists once
/// its script has run.
@MainActor
struct RenderedPageReaderTests {
    @Test(.timeLimit(.minutes(1)))
    func readsJSONLDThatAScriptAdds() async throws {
        let html = try Fixture.html("js-rendered-only")
        let pageURL = Fixture.pageURL("js-rendered-only")
        // The parsers alone see nothing in the served HTML.
        #expect(throws: RecipeImportError.noRecipeFound) {
            try RecipeImporter.parse(html: html, sourceURL: pageURL)
        }

        let draft = try #require(await RenderedPageReader.recipe(inHTML: html, baseURL: pageURL, timeout: .seconds(20)))
        #expect(draft.title == "Sesame Noodles")
        #expect(draft.ingredients.count == 6)
        #expect(draft.steps.count == 3)
        #expect(draft.servings == 4)
        #expect(draft.totalTime == 1_200)
        #expect(draft.imageURL == URL(string: "https://example.com/static/sesame-noodles.jpg"))
    }
}
#endif
