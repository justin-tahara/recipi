import Foundation
import Testing
@testable import RecipiKit

struct AutoTaggerTests {
    private func draft(
        _ title: String = "Test recipe",
        tags: [String] = [],
        diets: [String] = [],
        calories: Double? = nil,
        protein: Double? = nil,
        totalTime: TimeInterval? = nil
    ) -> RecipeDraft {
        var draft = RecipeDraft(title: title)
        draft.tags = tags
        draft.diets = diets
        if calories != nil || protein != nil {
            draft.nutrition = RecipeDraft.Nutrition(calories: calories, proteinGrams: protein)
        }
        draft.totalTime = totalTime
        return draft
    }

    private func names(_ draft: RecipeDraft) -> [String] {
        AutoTagger.tags(for: draft).map(\.name)
    }

    // MARK: Mapping

    @Test func mapsCategoriesCuisinesAndKeywordsOntoTheVocabulary() {
        let tags = AutoTagger.tags(for: draft(tags: ["Main Course", "italiano", "vegetariano", "pasta"]))
        #expect(tags == [
            AutoTag("Dinner", kind: .meal),
            AutoTag("Italian", kind: .cuisine),
            AutoTag("Vegetarian", kind: .diet),
            AutoTag("pasta"),
        ])
    }

    @Test func synonymsOfOneTermBecomeOneTag() {
        #expect(names(draft(tags: ["Japanese", "japonais", "和食", "Japanese Recipes"])) == ["Japanese"])
    }

    @Test func aPhraseOfTermsGivesEachTerm() {
        #expect(names(draft(tags: ["easy vegetarian dinner"])) == ["Vegetarian", "Dinner"])
    }

    @Test func schemaDietsAreMapped() {
        let tags = names(draft(diets: ["https://schema.org/VeganDiet", "GlutenFreeDiet", "https://schema.org/HalalDiet"]))
        #expect(tags == ["Vegan", "Gluten-free"])
    }

    // MARK: Keyword cap

    @Test func keepsAtMostThreeOtherKeywords() {
        let tags = names(draft(tags: ["Dinner", "chicken", "pasta", "tomato", "basil", "garlic"]))
        #expect(tags == ["Dinner", "chicken", "pasta", "tomato"])
        #expect(AutoTagger.maxFreeFormTags == 3)
    }

    @Test func dropsJunkKeywordsWithoutCountingThem() {
        let tags = names(draft("Fluffy Pancakes", tags: [
            "the best fluffy buttermilk pancakes ever",
            "fluffy pancakes",
            "pancake recipe",
            "how to make pancakes",
            "https://example.com",
            "2024",
            "5 ingredients",
            "easy best",
            "x",
            "pancakes",
            "buttermilk",
        ]))
        #expect(tags == ["pancakes", "buttermilk"])
    }

    @Test func keywordsAreDedupedIgnoringCase() {
        #expect(names(draft(tags: ["Pasta", "pasta", "PASTA"])) == ["Pasta"])
    }

    // MARK: Traits from nutrition

    @Test(arguments: [(30.0, true), (25.0, true), (24.9, false), (8.0, false)])
    func highProteinFromProteinPerServing(protein: Double, expected: Bool) {
        #expect(names(draft(protein: protein)).contains("High protein") == expected)
    }

    @Test(arguments: [(320.0, true), (450.0, true), (451.0, false), (900.0, false)])
    func lightFromCaloriesPerServing(calories: Double, expected: Bool) {
        #expect(names(draft(calories: calories)).contains("Light") == expected)
    }

    @Test func dessertsAndDrinksAreNotLightByCalories() {
        #expect(!names(draft(tags: ["Dessert"], calories: 180)).contains("Light"))
        #expect(!names(draft(tags: ["Cocktails"], calories: 150)).contains("Light"))
    }

    @Test(arguments: [(1_500.0, true), (1_800.0, true), (1_801.0, false), (5_400.0, false)])
    func quickFromTotalTime(seconds: TimeInterval, expected: Bool) {
        #expect(names(draft(totalTime: seconds)).contains("Quick") == expected)
    }

    @Test func quickFallsBackToPrepPlusCook() {
        var quick = draft()
        quick.prepTime = 600
        quick.cookTime = 900
        #expect(names(quick).contains("Quick"))

        var cookOnly = draft()
        cookOnly.cookTime = 600
        #expect(!names(cookOnly).contains("Quick"), "Without prep time the total isn't known")
    }

    @Test func measuredValuesWinOverKeywords() {
        let tags = names(draft(tags: ["Quick", "Light", "High Protein"], calories: 800, protein: 10, totalTime: 7_200))
        #expect(tags.isEmpty)
    }

    @Test func keywordTraitsStandWhenNothingIsMeasured() {
        #expect(names(draft(tags: ["quick", "low calorie"])) == ["Quick", "Light"])
    }

    @Test func noNutritionAndNoTimeMeansNoTraits() {
        #expect(names(draft("Roast chicken")).isEmpty)
    }

    // MARK: Heuristics without nutrition

    @Test(arguments: [
        ("Simple Green Salad", true),
        ("Salade niçoise", true),
        ("Kale and quinoa salad", true),
        ("Creamy potato salad", false),
        ("Pasta Salad", false),
        ("Caesar salad dressing", false),
        ("Roast chicken", false),
    ])
    func saladsAreLightWithoutNutrition(title: String, expected: Bool) {
        #expect(names(draft(title)).contains("Light") == expected)
    }

    @Test func caloriesBeatTheSaladGuess() {
        #expect(!names(draft("Loaded taco salad bowl", calories: 900)).contains("Light"))
    }

    @Test func proteinInTheTitleCountsWithoutNutrition() {
        #expect(names(draft("Protein pancakes")).contains("High protein"))
        #expect(!names(draft("Protein pancakes", protein: 12)).contains("High protein"))
    }
}

struct SchemaTagHintsTests {
    @Test(arguments: [
        ("320 kcal", 320.0),
        ("320 calories", 320.0),
        ("Calories: 410", 410.0),
        ("1,200 calories", 1_200.0),
        ("1340 kJ", 1_340.0 / 4.184),
    ])
    func readsCalories(text: String, expected: Double) throws {
        let nutrition = try #require(SchemaTagHints.nutrition(from: ["calories": text]))
        let calories = try #require(nutrition.calories)
        #expect(abs(calories - expected) < 0.01)
    }

    @Test(arguments: [
        ("28 g", 28.0),
        ("28g", 28.0),
        ("28,5 g", 28.5),
        ("31.2 grams", 31.2),
        ("2500 mg", 2.5),
    ])
    func readsProtein(text: String, expected: Double) throws {
        let nutrition = try #require(SchemaTagHints.nutrition(from: ["proteinContent": text]))
        let protein = try #require(nutrition.proteinGrams)
        #expect(abs(protein - expected) < 0.01)
    }

    @Test func readsNumbersAndArrays() {
        let value: [[String: Any]] = [["@type": "NutritionInformation", "calories": 250, "proteinContent": 30]]
        let nutrition = SchemaTagHints.nutrition(from: value)
        #expect(nutrition == RecipeDraft.Nutrition(calories: 250, proteinGrams: 30))
    }

    @Test func ignoresImpossibleOrMissingValues() {
        #expect(SchemaTagHints.nutrition(from: ["calories": "0 kcal", "proteinContent": "n/a"]) == nil)
        #expect(SchemaTagHints.nutrition(from: ["calories": "99999"]) == nil)
        #expect(SchemaTagHints.nutrition(from: "nope") == nil)
        #expect(SchemaTagHints.nutrition(from: nil) == nil)
    }

    @Test func readsDiets() {
        #expect(SchemaTagHints.diets(from: "https://schema.org/VegetarianDiet") == ["VegetarianDiet"])
        let mixed: [Any] = ["schema:VeganDiet", ["@id": "http://schema.org/GlutenFreeDiet"]]
        #expect(SchemaTagHints.diets(from: mixed) == ["VeganDiet", "GlutenFreeDiet"])
        #expect(SchemaTagHints.diets(from: nil) == [])
    }

    @Test func schemaParserReadsNutritionAndDiets() throws {
        let html = """
        <script type="application/ld+json">
        {"@context": "https://schema.org", "@type": "Recipe", "name": "Chicken Teriyaki Bowl",
         "recipeCuisine": "Japanese", "recipeCategory": "Main Course",
         "keywords": "teriyaki, rice bowl, chicken teriyaki bowl, easy chicken teriyaki recipe",
         "totalTime": "PT25M",
         "suitableForDiet": "https://schema.org/GlutenFreeDiet",
         "nutrition": {"@type": "NutritionInformation", "calories": "520 kcal", "proteinContent": "38 g"},
         "recipeIngredient": ["2 chicken thighs", "1 cup rice"],
         "recipeInstructions": "Cook the rice. Glaze the chicken."}
        </script>
        """
        let draft = try #require(SchemaRecipeParser.parse(html: html))
        #expect(draft.nutrition == RecipeDraft.Nutrition(calories: 520, proteinGrams: 38))
        #expect(draft.diets == ["GlutenFreeDiet"])
        // The parser keeps the page's own values; tidying happens on save.
        #expect(draft.tags == ["Main Course", "Japanese", "teriyaki", "rice bowl", "chicken teriyaki bowl", "easy chicken teriyaki recipe"])

        let tags = AutoTagger.tags(for: draft).map(\.name)
        #expect(tags == ["Dinner", "Japanese", "Gluten-free", "High protein", "Quick", "teriyaki", "rice bowl"])
    }
}
