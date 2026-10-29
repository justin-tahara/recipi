import Foundation
import RecipiKit
import Testing
@testable import Recipi

/// The UI tests import through `FixtureURLProtocol`; these check that it
/// serves the fixture page and answers everything else itself.
struct FixtureImportTests {
    private let importer: RecipeImporter = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        // No offscreen web view: it would load the page over the real network.
        return RecipeImporter(session: URLSession(configuration: configuration), rendersJavaScript: false)
    }()

    @Test func importsTheFixturePage() async throws {
        let draft = try await importer.importRecipe(from: FixturePages.lemonSpaghettiURL)
        #expect(draft.title == "Lemon Garlic Spaghetti")
        #expect(draft.sourceURL == FixturePages.lemonSpaghettiURL)
        #expect(draft.servings == 4)
        #expect(draft.ingredients.map(\.text) == ["400 g spaghetti", "2 lemons", "4 cloves garlic", "60 g parmesan"])
        #expect(draft.steps.count == 2)
        #expect(draft.imageURL == nil)
    }

    @Test func otherLinksGetAnEmptyPage() async {
        await #expect(throws: RecipeImportError.self) {
            try await importer.importRecipe(from: URL(string: "https://example.com/not-a-fixture")!)
        }
    }
}
