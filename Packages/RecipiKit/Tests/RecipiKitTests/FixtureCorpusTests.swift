import Foundation
import Testing
@testable import RecipiKit

/// What each fixture in `Fixtures/` should import as. When a real site
/// fails, add its trimmed page (see `scripts/capture_fixture.py`) and a row
/// here before changing a parser.
struct FixtureExpectation: Sendable, CustomTestStringConvertible {
    var file: String
    var title: String
    var ingredients: Int
    var steps: Int
    var servings: Int?
    var yieldText: String?
    var imageURL: String?
    var prepTime: TimeInterval?
    var cookTime: TimeInterval?
    var totalTime: TimeInterval?
    /// Runs of ingredient sections in order, as "Name×count".
    var ingredientSections: [String] = []
    /// Runs of step sections in order, as "Name×count"; "–" for none.
    var stepSections: [String] = []

    var testDescription: String { file }

    static let all: [FixtureExpectation] = [
        FixtureExpectation(
            file: "yoast-graph", title: "Lemon Ricotta Pancakes", ingredients: 8, steps: 4,
            servings: 4, yieldText: "4 servings",
            imageURL: "https://example.com/wp-content/uploads/2024/03/lemon-ricotta-pancakes.jpg",
            prepTime: 600, cookTime: 1_200, totalTime: 1_800
        ),
        FixtureExpectation(
            file: "wprm-sections", title: "Weeknight Chicken Enchiladas", ingredients: 7, steps: 5,
            servings: 8, yieldText: "8 enchiladas",
            imageURL: "https://example.org/wp-content/uploads/enchiladas.jpg",
            prepTime: 1_200, cookTime: 1_500, totalTime: 2_700,
            ingredientSections: ["Red sauce×4", "Filling×3"],
            stepSections: ["Sauce×2", "Assembly×3"]
        ),
        FixtureExpectation(
            file: "wprm-html-only", title: "Grandma’s Apple Pie", ingredients: 6, steps: 4,
            servings: 8, yieldText: "8",
            imageURL: "https://example.com/wp-content/uploads/apple-pie.jpg",
            ingredientSections: ["Pastry×3", "Filling×3"]
        ),
        FixtureExpectation(
            file: "tasty-recipes", title: "Brown Butter Chocolate Chip Cookies", ingredients: 9, steps: 4,
            servings: 24, yieldText: "24 cookies",
            imageURL: "https://example.net/wp-content/uploads/cookies-225x225.jpg",
            prepTime: 1_200, cookTime: 720, totalTime: 1_920
        ),
        FixtureExpectation(
            file: "tasty-html-only", title: "Sheet Pan Gnocchi with Sausage and Peppers", ingredients: 7, steps: 4,
            servings: 4, yieldText: "4 servings",
            imageURL: "https://example.net/uploads/sheet-pan-gnocchi.jpg",
            ingredientSections: ["For the pan×5", "To finish×2"]
        ),
        FixtureExpectation(
            file: "dotdash-array-type", title: "Classic Beef Chili", ingredients: 9, steps: 4,
            servings: 8, yieldText: "8",
            imageURL: "https://www.example.com/thmb/classic-beef-chili-4x3.jpg",
            prepTime: 900, cookTime: 3_600, totalTime: 4_500
        ),
        FixtureExpectation(
            file: "howto-sections-nested", title: "Overnight Focaccia", ingredients: 5, steps: 7,
            servings: 1, yieldText: "1 sheet pan",
            imageURL: "https://example.com/images/focaccia.jpg",
            prepTime: 1_200, cookTime: 1_500, totalTime: 50_400,
            stepSections: ["The night before×3", "Baking day×3", "–×1"]
        ),
        FixtureExpectation(
            file: "instructions-plain-string", title: "Quick Pickled Onions", ingredients: 5, steps: 3,
            servings: 2, yieldText: "2",
            imageURL: "https://example.com/pickled-onions.jpg",
            prepTime: 600, totalTime: 2_400
        ),
        FixtureExpectation(
            file: "instructions-html-string", title: "Green Goddess Dressing", ingredients: 6, steps: 4,
            servings: 1, yieldText: "About 1 1/2 cups",
            imageURL: "https://example.com/media/green-goddess.jpg",
            prepTime: 600, totalTime: 600
        ),
        FixtureExpectation(
            file: "yield-range-string-image", title: "Roasted Tomato Soup", ingredients: 6, steps: 3,
            servings: 4, yieldText: "Serves 4-6",
            imageURL: "https://example.com/media/roasted-tomato-soup.jpg",
            prepTime: 900, cookTime: 2_700
        ),
        FixtureExpectation(
            file: "image-object-array", title: "Miso Glazed Salmon", ingredients: 5, steps: 3,
            servings: 2, yieldText: "2 servings",
            imageURL: "https://cdn.example.com/salmon/1x1-300.jpg",
            prepTime: 300, cookTime: 720, totalTime: 1_020
        ),
        FixtureExpectation(
            file: "odd-durations", title: "Slow Cooker Pulled Pork", ingredients: 5, steps: 3,
            servings: 10, yieldText: "10",
            imageURL: "https://example.com/pulled-pork.jpg",
            prepTime: 1_200, cookTime: 28_800, totalTime: 30_000
        ),
        FixtureExpectation(
            file: "zero-times", title: "Simple Green Salad", ingredients: 4, steps: 2,
            servings: nil, yieldText: "A big bowl",
            imageURL: "https://example.com/green-salad.jpg",
            prepTime: 600
        ),
        FixtureExpectation(
            file: "entities-nested-markup", title: "Mom's Baked Mac & Cheese", ingredients: 7, steps: 3,
            servings: 6, yieldText: "6",
            imageURL: "https://example.com/mac-and-cheese.jpg",
            prepTime: 900, cookTime: 1_800, totalTime: 2_700
        ),
        FixtureExpectation(
            file: "multiple-blocks-one-invalid", title: "Banana Bread", ingredients: 7, steps: 3,
            servings: 1, yieldText: "1 loaf",
            imageURL: "https://example.com/banana-bread.jpg",
            prepTime: 900, cookTime: 3_600, totalTime: 4_500
        ),
        FixtureExpectation(
            file: "microdata-only", title: "Classic Buttermilk Biscuits", ingredients: 5, steps: 4,
            servings: 10, yieldText: "10 biscuits",
            imageURL: "https://example.com/images/biscuits-large.jpg",
            prepTime: 900, cookTime: 720, totalTime: 1_620
        ),
        FixtureExpectation(
            file: "microdata-instruction-container", title: "Red Lentil Soup", ingredients: 6, steps: 4,
            servings: 6, yieldText: "Serves 6",
            imageURL: "https://example.com/photos/lentil-soup.jpg"
        ),
        FixtureExpectation(
            file: "lang-de", title: "Käsespätzle mit Röstzwiebeln", ingredients: 7, steps: 4,
            servings: 4, yieldText: "4 Portionen",
            imageURL: "https://example.de/bilder/kaesespaetzle.jpg",
            prepTime: 1_800, cookTime: 1_200, totalTime: 3_000
        ),
        FixtureExpectation(
            file: "lang-fr", title: "Bœuf bourguignon", ingredients: 9, steps: 4,
            servings: 6, yieldText: "6 personnes",
            imageURL: "https://example.fr/photos/boeuf-bourguignon.jpg",
            prepTime: 1_800, cookTime: 10_800, totalTime: 12_600,
            stepSections: ["La veille×1", "Le jour même×3"]
        ),
        FixtureExpectation(
            file: "lang-it", title: "Spaghetti alla carbonara", ingredients: 6, steps: 4,
            servings: 4, yieldText: "4 persone",
            imageURL: "https://example.it/img/carbonara.jpg",
            prepTime: 600, cookTime: 900, totalTime: 1_500
        ),
        FixtureExpectation(
            file: "lang-ja", title: "ふわとろ親子丼", ingredients: 8, steps: 4,
            servings: 2, yieldText: "2人分",
            imageURL: "https://example.jp/images/oyakodon.jpg",
            prepTime: 600, cookTime: 900, totalTime: 1_500
        ),
    ]
}

struct FixtureCorpusTests {
    @Test(arguments: FixtureExpectation.all)
    func importsFixture(_ expected: FixtureExpectation) throws {
        let html = try Fixture.html(expected.file)
        let draft = try RecipeImporter.parse(html: html, sourceURL: Fixture.pageURL(expected.file))

        #expect(draft.title == expected.title)
        #expect(draft.ingredients.count == expected.ingredients)
        #expect(draft.steps.count == expected.steps)
        #expect(draft.servings == expected.servings)
        #expect(draft.yieldText == expected.yieldText)
        #expect(draft.imageURL?.absoluteString == expected.imageURL)
        #expect(draft.prepTime == expected.prepTime)
        #expect(draft.cookTime == expected.cookTime)
        #expect(draft.totalTime == expected.totalTime)
        #expect(sectionRuns(draft.ingredients) == expected.ingredientSections)
        #expect(sectionRuns(draft.steps) == expected.stepSections)

        // Nothing should leak through as markup, entities or checkbox glyphs.
        for line in [draft.title] + draft.ingredients.map(\.text) + draft.steps.map(\.text) {
            #expect(!line.isEmpty)
            #expect(!line.contains("<"), "Markup left in \(line)")
            #expect(line.range(of: "&#?[A-Za-z0-9]+;", options: .regularExpression) == nil, "Entity left in \(line)")
            #expect(!line.contains("▢"), "Checkbox glyph left in \(line)")
        }
    }

    @Test func corpusIsBigEnough() {
        #expect(FixtureExpectation.all.count >= 20)
        #expect(Set(FixtureExpectation.all.map(\.file)).count == FixtureExpectation.all.count)
    }

    @Test(arguments: ["js-rendered-only", "amp-canonical", "meta-refresh"])
    func pagesWithoutRecipeDataInTheirHTML(_ file: String) throws {
        let html = try Fixture.html(file)
        #expect(throws: RecipeImportError.noRecipeFound) {
            try RecipeImporter.parse(html: html, sourceURL: Fixture.pageURL(file))
        }
    }

    // MARK: - Details the table doesn't cover

    @Test func resolvesYoastGraphReferences() throws {
        let draft = try RecipeImporter.parse(html: Fixture.html("yoast-graph"), sourceURL: nil)
        #expect(draft.author == "Robin Ellis")
        #expect(draft.tags == ["Breakfast", "American", "pancakes", "ricotta"])
    }

    @Test func takesIngredientGroupsFromTheRecipeCard() throws {
        let draft = try RecipeImporter.parse(html: Fixture.html("wprm-sections"), sourceURL: nil)
        // The text still comes from the JSON-LD; only the headings are added.
        #expect(draft.ingredients.first == RecipeDraft.Line("2 tablespoons olive oil", section: "Red sauce"))
        #expect(draft.ingredients.last == RecipeDraft.Line("2 cups grated cheddar", section: "Filling"))
        #expect(draft.steps.last?.text == "Bake at 400°F for 20 minutes.")
    }

    @Test func readsWordPressRecipeMakerCardWithoutJSONLD() throws {
        let html = try Fixture.html("wprm-sections")
        let draft = try #require(FallbackRecipeParser.parse(html: html))
        #expect(draft.ingredients.map(\.text) == [
            "2 tablespoons olive oil", "2 tablespoons flour", "2 tablespoons chili powder", "2 cups chicken stock",
            "3 cups shredded cooked chicken", "8 flour tortillas", "2 cups grated cheddar",
        ])
        #expect(draft.steps.map(\.section) == ["Sauce", "Sauce", "Assembly", "Assembly", "Assembly"])
    }

    @Test func joinsParagraphsInsideOneStep() throws {
        let draft = try RecipeImporter.parse(html: Fixture.html("wprm-html-only"), sourceURL: nil)
        #expect(draft.steps.first?.text == "Cut the butter into the flour until it looks like coarse crumbs. Stir in the water.")
        #expect(draft.ingredients.first?.text == "2 ½ cups flour")
        #expect(draft.summary == "A double-crust apple pie with a flaky all-butter pastry.")
    }

    @Test func readsMetaContentWithAnApostrophe() throws {
        let html = try Fixture.html("wprm-html-only")
        #expect(HTMLText.metaContent("og:title", in: html) == "Grandma's Apple Pie")
    }

    @Test func dropsTastyCheckboxesAndHeaders() throws {
        let draft = try RecipeImporter.parse(html: Fixture.html("tasty-html-only"), sourceURL: nil)
        #expect(draft.ingredients.first?.text == "1 pound shelf-stable gnocchi")
        #expect(draft.steps.first?.text == "Heat the oven to 425°F.")
    }

    @Test func splitsHTMLInstructionsIntoSteps() throws {
        let draft = try RecipeImporter.parse(html: Fixture.html("instructions-html-string"), sourceURL: nil)
        #expect(draft.steps.map(\.text) == [
            "Put everything in a blender.",
            "Blend until smooth and pale green.",
            "Taste and season with salt and pepper.",
            "Keeps for a week in the fridge.",
        ])
        #expect(draft.summary == "Herby, tangy and great on everything.")
    }

    @Test func decodesEntitiesAndStripsMarkup() throws {
        let draft = try RecipeImporter.parse(html: Fixture.html("entities-nested-markup"), sourceURL: nil)
        #expect(draft.summary == "Creamy, crunchy & ready in under an hour…")
        #expect(draft.ingredients.map(\.text).contains("2 ½ cups sharp cheddar"))
        #expect(draft.ingredients.map(\.text).contains("1 cup Gruyère"))
        #expect(draft.ingredients.last?.text == "⅓ cup panko")
        #expect(draft.steps.first?.text == "Boil the pasta until just shy of al dente – it finishes in the oven.")
        #expect(draft.tags == ["mac & cheese", "comfort food"])
    }

    @Test func readsMicrodataScalarsOutsideNestedItems() throws {
        let draft = try RecipeImporter.parse(html: Fixture.html("microdata-only"), sourceURL: nil)
        #expect(draft.summary == "Tall, flaky biscuits with a crisp top.")
        #expect(draft.ingredients.last?.text == "3/4 cup cold buttermilk")
        #expect(draft.steps.first?.text == "Whisk the flour, baking powder and salt.")
    }

    @Test func keepsNonEnglishTextIntact() throws {
        let german = try RecipeImporter.parse(html: Fixture.html("lang-de"), sourceURL: nil)
        #expect(german.ingredients.map(\.text).contains("2 EL Butter"))
        #expect(german.author == "Jana Müller")
        let japanese = try RecipeImporter.parse(html: Fixture.html("lang-ja"), sourceURL: nil)
        #expect(japanese.ingredients.map(\.text).contains("醤油 大さじ2"))
        let italian = try RecipeImporter.parse(html: Fixture.html("lang-it"), sourceURL: nil)
        #expect(italian.ingredients.last?.text == "1 cucchiaio di pepe nero macinato")
    }

    private func sectionRuns(_ lines: [RecipeDraft.Line]) -> [String] {
        guard lines.contains(where: { $0.section != nil }) else { return [] }
        var runs: [(name: String, count: Int)] = []
        for line in lines {
            let name = line.section ?? "–"
            if runs.last?.name == name {
                runs[runs.count - 1].count += 1
            } else {
                runs.append((name, 1))
            }
        }
        return runs.map { "\($0.name)×\($0.count)" }
    }
}
