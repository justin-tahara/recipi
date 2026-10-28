import Foundation
import Testing
@testable import RecipiKit

struct SchemaRecipeParserTests {
    private let pageURL = URL(string: "https://example.com/recipes/pancakes")!

    @Test func readsARecipeInsideAGraph() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@context": "https://schema.org", "@graph": [
          {"@type": "WebPage", "name": "Pancakes page"},
          {"@type": ["Recipe"], "name": "Fluffy Pancakes",
           "description": "Weekend pancakes &amp; syrup",
           "author": [{"@type": "Person", "name": "Sam Cook"}],
           "image": [{"@type": "ImageObject", "url": "/img/pancakes.jpg"}],
           "recipeYield": ["4", "4 servings"],
           "prepTime": "PT10M", "cookTime": "PT15M", "totalTime": "PT25M",
           "recipeCategory": "Breakfast", "keywords": "pancakes, breakfast, easy",
           "recipeIngredient": ["1 1/2 cups flour", "1 egg", "1 1/4 cups milk"],
           "recipeInstructions": [
             {"@type": "HowToSection", "name": "Batter", "itemListElement": [
               {"@type": "HowToStep", "text": "Whisk the dry ingredients."},
               {"@type": "HowToStep", "text": "Add egg and milk."}
             ]},
             {"@type": "HowToStep", "text": "Cook on a hot griddle."}
           ]}
        ]}
        </script></head><body></body></html>
        """

        let draft = try #require(SchemaRecipeParser.parse(html: html, sourceURL: pageURL))
        #expect(draft.title == "Fluffy Pancakes")
        #expect(draft.summary == "Weekend pancakes & syrup")
        #expect(draft.author == "Sam Cook")
        #expect(draft.imageURL == URL(string: "https://example.com/img/pancakes.jpg"))
        #expect(draft.servings == 4)
        #expect(draft.prepTime == 600)
        #expect(draft.totalTime == 1_500)
        #expect(draft.ingredients.map(\.text) == ["1 1/2 cups flour", "1 egg", "1 1/4 cups milk"])
        #expect(draft.steps.map(\.text) == ["Whisk the dry ingredients.", "Add egg and milk.", "Cook on a hot griddle."])
        #expect(draft.steps.map(\.section) == ["Batter", "Batter", nil])
        #expect(draft.tags == ["Breakfast", "pancakes", "easy"])
    }

    @Test func readsPlainStringInstructions() throws {
        let html = """
        <script type='application/ld+json'>
        {"@type": "Recipe", "name": "Toast", "recipeIngredient": "1 slice bread",
         "recipeInstructions": "Toast the bread.<br>Butter it."}
        </script>
        """
        let draft = try #require(SchemaRecipeParser.parse(html: html))
        #expect(draft.ingredients.map(\.text) == ["1 slice bread"])
        #expect(draft.steps.map(\.text) == ["Toast the bread.", "Butter it."])
    }

    @Test func ignoresPagesWithoutARecipe() {
        let html = #"<script type="application/ld+json">{"@type": "Article", "name": "News"}</script>"#
        #expect(SchemaRecipeParser.parse(html: html) == nil)
    }
}

struct FallbackRecipeParserTests {
    @Test func readsMicrodata() throws {
        let html = """
        <html><head><title>Grandma's Soup | Example</title></head><body>
        <ul>
          <li itemprop="recipeIngredient">2 carrots</li>
          <li itemprop="recipeIngredient">1 <b>onion</b></li>
        </ul>
        <ol itemprop="recipeInstructions"><li>Chop.</li><li>Simmer.</li></ol>
        </body></html>
        """
        let draft = try #require(FallbackRecipeParser.parse(html: html))
        #expect(draft.title == "Grandma's Soup | Example")
        #expect(draft.ingredients.map(\.text) == ["2 carrots", "1 onion"])
        #expect(draft.steps.map(\.text) == ["Chop.", "Simmer."])
    }

    @Test func readsWordPressRecipeMakerMarkup() throws {
        let html = """
        <meta property="og:title" content="Best Brownies">
        <ul>
          <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-amount">1</span> <span class="wprm-recipe-ingredient-unit">cup</span> sugar</li>
          <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-amount">2</span> eggs</li>
        </ul>
        <div class="wprm-recipe-instruction-text">Mix everything.</div>
        """
        let draft = try #require(FallbackRecipeParser.parse(html: html))
        #expect(draft.title == "Best Brownies")
        #expect(draft.ingredients.map(\.text) == ["1 cup sugar", "2 eggs"])
        #expect(draft.steps.map(\.text) == ["Mix everything."])
    }

    @Test func importerFallsBackAndThenGivesUp() {
        #expect(throws: RecipeImportError.noRecipeFound) {
            try RecipeImporter.parse(html: "<html><body>Hello</body></html>", sourceURL: nil)
        }
    }
}
