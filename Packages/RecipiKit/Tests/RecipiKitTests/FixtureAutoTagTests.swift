import Foundation
import Testing
@testable import RecipiKit

/// Automatic tags for the pages in `Fixtures/`, from import to tags, as
/// `Recipe.insert(from:)` applies them.
struct FixtureAutoTagTests {
    @Test(arguments: [
        ("yoast-graph", ["Breakfast", "American", "Quick", "pancakes", "ricotta"]),
        ("wprm-sections", ["Dinner", "Mexican", "enchiladas"]),
        // 423 kcal a serving is under the "Light" threshold.
        ("dotdash-array-type", ["Dinner", "American", "Light"]),
        ("tasty-recipes", ["Dessert", "American"]),
        // "Hauptgericht", "Schwäbisch".
        ("lang-de", ["Dinner", "German"]),
        // "Primi piatti", "Romana", 25 minutes.
        ("lang-it", ["Dinner", "Italian", "Quick"]),
        ("lang-ja", ["Quick"]),
        ("lang-fr", []),
        ("image-object-array", ["Quick"]),
        // No calories, but it's a green salad.
        ("zero-times", ["Light"]),
        ("entities-nested-markup", ["mac & cheese", "comfort food"]),
        ("howto-sections-nested", []),
    ])
    func autoTags(file: String, expected: [String]) throws {
        let draft = try RecipeImporter.parse(html: Fixture.html(file), sourceURL: Fixture.pageURL(file))
        #expect(AutoTagger.tags(for: draft).map(\.name) == expected)
    }

    /// Whatever a page says, the tags stay tidy: vocabulary tags under
    /// their own names, no duplicates, and only a few other keywords.
    @Test(arguments: FixtureExpectation.all)
    func tagsAreTidy(_ fixture: FixtureExpectation) throws {
        let draft = try RecipeImporter.parse(html: Fixture.html(fixture.file), sourceURL: Fixture.pageURL(fixture.file))
        let tags = AutoTagger.tags(for: draft)
        let keys = tags.map { TagVocabulary.normalized($0.name) }
        #expect(Set(keys).count == keys.count)
        #expect(tags.filter { $0.kind == nil }.count <= AutoTagger.maxFreeFormTags)
        for tag in tags {
            if let kind = tag.kind {
                #expect(TagVocabulary.term(named: tag.name)?.kind == kind)
            } else {
                #expect(TagVocabulary.term(matching: tag.name) == nil)
            }
        }
    }
}
