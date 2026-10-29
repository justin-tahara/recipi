import Foundation
import SwiftData
import Testing
@testable import RecipiKit

// MARK: - Samples

/// Short recipes as they'd come from a site in each language.
private enum Sample {
    static let french = RecipeText(
        title: "Bœuf bourguignon",
        summary: "Le classique mijoté au vin rouge, encore meilleur le lendemain.",
        ingredients: [
            .init("1,5 kg de bœuf à braiser"),
            .init("75 cl de vin rouge"),
            .init("200 g de lardons"),
            .init("2 cuillères à soupe de farine"),
        ],
        steps: [
            .init("Couper la viande en cubes et la faire mariner dans le vin avec l’oignon.", section: "La veille"),
            .init("Égoutter la viande et la faire dorer avec les lardons.", section: "Le jour même"),
            .init("Saupoudrer de farine, mouiller avec la marinade et laisser mijoter trois heures.", section: "Le jour même"),
        ]
    )

    static let italian = RecipeText(
        title: "Spaghetti alla carbonara",
        summary: "La ricetta romana con guanciale, uova e pecorino.",
        ingredients: [
            .init("320 g di spaghetti"),
            .init("150 g di guanciale"),
            .init("4 tuorli"),
            .init("1 cucchiaio di pepe nero macinato"),
        ],
        steps: [
            .init("Tagliate il guanciale a listarelle e rosolatelo in padella senza olio."),
            .init("Sbattete i tuorli con il pecorino e il pepe."),
            .init("Cuocete gli spaghetti al dente e scolateli tenendo un po’ d’acqua di cottura."),
        ]
    )

    static let spanish = RecipeText(
        title: "Tortilla de patatas",
        summary: "La tortilla española de toda la vida, jugosa por dentro.",
        ingredients: [
            .init("500 g de patatas"),
            .init("6 huevos"),
            .init("1 cebolla"),
            .init("4 cucharadas de aceite de oliva"),
        ],
        steps: [
            .init("Pelar las patatas y cortarlas en láminas finas."),
            .init("Freír las patatas y la cebolla a fuego lento hasta que estén tiernas."),
            .init("Batir los huevos, mezclarlos con las patatas y cuajar la tortilla por los dos lados."),
        ]
    )

    static let german = RecipeText(
        title: "Käsespätzle mit Röstzwiebeln",
        summary: "Hausgemachte Spätzle mit viel Bergkäse und knusprigen Zwiebeln.",
        ingredients: [
            .init("400 g Mehl"),
            .init("4 Eier"),
            .init("1 TL Salz"),
            .init("2 EL Butter"),
        ],
        steps: [
            .init("Mehl, Eier, Wasser und Salz zu einem zähen Teig schlagen und 15 Minuten ruhen lassen."),
            .init("Den Teig portionsweise in kochendes Salzwasser schaben und abtropfen lassen."),
            .init("Die Zwiebeln in Ringe schneiden und in der Butter goldbraun rösten."),
        ]
    )

    static let japanese = RecipeText(
        title: "ふわとろ親子丼",
        summary: "鶏もも肉と卵でつくる定番の丼。",
        ingredients: [
            .init("鶏もも肉 300g"),
            .init("玉ねぎ 1/2個"),
            .init("醤油 大さじ2"),
            .init("砂糖 小さじ1"),
        ],
        steps: [
            .init("鶏肉はひと口大に、玉ねぎは薄切りにする。"),
            .init("小さめの鍋にだし、醤油、みりん、砂糖を煮立て、鶏肉と玉ねぎを入れて5分煮る。"),
            .init("溶き卵を2回に分けて回し入れ、半熟で火を止める。"),
        ]
    )

    static let english = RecipeText(
        title: "Pasta with tomato sauce",
        summary: "A quick weeknight pasta.",
        ingredients: [.init("400 g spaghetti"), .init("2 tbsp olive oil", section: "For the sauce")],
        steps: [.init("Warm the oil and add the tomatoes."), .init("Boil the pasta until it is just tender.")]
    )
}

// MARK: - Detection

struct RecipeLanguageDetectionTests {
    @Test(arguments: [
        (Sample.french, "fr"),
        (Sample.italian, "it"),
        (Sample.spanish, "es"),
        (Sample.german, "de"),
        (Sample.japanese, "ja"),
        (Sample.english, "en"),
    ])
    func detectsTheRecipeLanguage(text: RecipeText, expected: String) {
        #expect(RecipeLanguage.detect(text) == expected)
    }

    /// The non-English pages in the import fixture corpus, imported the way
    /// the app imports them.
    @Test(arguments: [("lang-fr", "fr"), ("lang-de", "de"), ("lang-it", "it"), ("lang-ja", "ja")])
    func detectsImportedFixtures(file: String, expected: String) throws {
        let draft = try RecipeImporter.parse(html: Fixture.html(file), sourceURL: nil)
        let text = RecipeText(
            title: draft.title,
            summary: draft.summary,
            ingredients: draft.ingredients.map { RecipeText.Line($0.text, section: $0.section) },
            steps: draft.steps.map { RecipeText.Line($0.text, section: $0.section) }
        )
        #expect(RecipeLanguage.detect(text) == expected)
    }

    @Test func englishFixturesAreEnglish() throws {
        for file in ["wprm-sections", "tasty-recipes", "microdata-only"] {
            let draft = try RecipeImporter.parse(html: Fixture.html(file), sourceURL: nil)
            let text = RecipeText(
                title: draft.title,
                summary: draft.summary,
                ingredients: draft.ingredients.map { RecipeText.Line($0.text) },
                steps: draft.steps.map { RecipeText.Line($0.text) }
            )
            #expect(RecipeLanguage.detect(text) == "en", "\(file)")
        }
    }

    @Test func saysNothingWithoutWords() {
        #expect(RecipeLanguage.detect("") == nil)
        #expect(RecipeLanguage.detect("250 / 2 · 30") == nil)
    }

    @Test func sampleIncludesHeadingsOnce() {
        let sample = Sample.french.languageSample
        #expect(sample.components(separatedBy: "Le jour même").count == 2)
        #expect(sample.hasPrefix("Bœuf bourguignon\n"))
    }

    @Test func comparesLanguagesIgnoringRegion() {
        #expect(RecipeLanguage.isSame("en", as: "en-US"))
        #expect(RecipeLanguage.isSame("en-GB", as: "en-US"))
        #expect(RecipeLanguage.isSame("pt-BR", as: "pt-PT"))
        #expect(!RecipeLanguage.isSame("fr", as: "en"))
        #expect(!RecipeLanguage.isSame("zh-Hans", as: "zh-Hant"))
    }

    @Test func namesLanguages() {
        let english = Locale(identifier: "en_US")
        #expect(RecipeLanguage.displayName(for: "fr", locale: english) == "French")
        #expect(RecipeLanguage.displayName(for: "ja", locale: english) == "Japanese")
        #expect(RecipeLanguage.displayName(for: "en-GB", locale: english) == "English")
        #expect(RecipeLanguage.displayName(for: "en-GB", includingRegion: true, locale: english) != "English")
    }
}

// MARK: - Settings

struct RecipeLanguageChoiceTests {
    @Test func storesAsText() {
        for choice: RecipeLanguageChoice in [.deviceLanguage, .dontTranslate, .language("fr"), .language("zh-Hant")] {
            #expect(RecipeLanguageChoice(rawValue: choice.rawValue) == choice)
        }
        #expect(RecipeLanguageChoice(rawValue: "") == nil)
    }

    @Test func picksTheTargetLanguage() {
        #expect(RecipeLanguageChoice.deviceLanguage.targetLanguage(deviceLanguage: "de") == "de")
        #expect(RecipeLanguageChoice.language("es").targetLanguage(deviceLanguage: "de") == "es")
        #expect(RecipeLanguageChoice.dontTranslate.targetLanguage(deviceLanguage: "de") == nil)
    }

    @Test func defaultsToDeviceLanguageAndABanner() {
        let suiteName = "RecipiKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(defaults.preference(PreferenceKeys.recipeLanguage) == .deviceLanguage)
        #expect(defaults.preference(PreferenceKeys.translateAutomatically) == false)

        defaults.setPreference(.language("ja"), for: PreferenceKeys.recipeLanguage)
        #expect(defaults.preference(PreferenceKeys.recipeLanguage) == .language("ja"))
        defaults.setPreference(.dontTranslate, for: PreferenceKeys.recipeLanguage)
        #expect(defaults.preference(PreferenceKeys.recipeLanguage) == .dontTranslate)
    }
}

// MARK: - Mapping translations back

struct RecipeTranslationPlanTests {
    /// Pretends to translate by upper-casing, so it's clear which text went
    /// through the translator.
    private func fakeTranslations(for plan: RecipeTranslationPlan) -> [String: String] {
        Dictionary(uniqueKeysWithValues: plan.segments.map { ($0.id, $0.text.uppercased()) })
    }

    @Test func translatesEachHeadingOnce() {
        let plan = RecipeTranslationPlan(Sample.french)
        let headings = plan.segments.filter { $0.id.hasPrefix("section.") }.map(\.text)
        #expect(headings == ["La veille", "Le jour même"])
    }

    @Test func keepsSectionsTogether() {
        let plan = RecipeTranslationPlan(Sample.french)
        let translated = plan.apply(fakeTranslations(for: plan))
        #expect(translated.steps.map(\.section) == ["LA VEILLE", "LE JOUR MÊME", "LE JOUR MÊME"])
        #expect(translated.steps.count == Sample.french.steps.count)
        #expect(translated.title == "BŒUF BOURGUIGNON")
    }

    @Test func keepsIngredientSectionsAndOrder() {
        let source = RecipeText(
            title: "Pasta",
            ingredients: [
                .init("400 g Spaghetti"),
                .init("2 EL Olivenöl", section: "Für die Sauce"),
                .init("1 Dose Tomaten", section: "Für die Sauce"),
                .init("Parmesan", section: "Zum Servieren"),
            ]
        )
        let plan = RecipeTranslationPlan(source)
        let translated = plan.apply(fakeTranslations(for: plan))
        #expect(translated.ingredients.map(\.section) == [nil, "FÜR DIE SAUCE", "FÜR DIE SAUCE", "ZUM SERVIEREN"])
        #expect(translated.ingredients.map(\.text) == ["400 G SPAGHETTI", "2 EL OLIVENÖL", "1 DOSE TOMATEN", "PARMESAN"])
    }

    @Test func keepsAmountsAsWritten() {
        let source = RecipeText(ingredients: [
            .init("1 1/2 cuillères à soupe de farine"),
            .init("2-3 gousses d’ail"),
            .init("½ oignon"),
            .init("350g Mehl"),
        ])
        let plan = RecipeTranslationPlan(source)
        // Only the words go to the translator.
        let ingredientTexts = plan.segments.filter { $0.id.hasPrefix("ingredient.") }.map(\.text)
        #expect(ingredientTexts == ["cuillères à soupe de farine", "gousses d’ail", "oignon", "Mehl"])

        let translated = plan.apply([
            "ingredient.0": "tablespoons of flour",
            "ingredient.1": "cloves of garlic",
            "ingredient.2": "onion",
            "ingredient.3": "flour",
        ])
        #expect(translated.ingredients.map(\.text) == [
            "1 1/2 tablespoons of flour", "2-3 cloves of garlic", "½ onion", "350g flour",
        ])

        // The parser reads the same amounts and units after translating.
        let parsed = translated.ingredients.map { IngredientParser.parse($0.text) }
        #expect(parsed.map(\.quantity) == [1.5, 2, 0.5, 350])
        #expect(parsed[0].unit == "tbsp")
        #expect(parsed[3].unit == "g")
        #expect(parsed[0].scaled(by: 2) == "3 tablespoons of flour")
    }

    @Test func translatesWholeLinesWithoutALeadingAmount() {
        let source = RecipeText(ingredients: [.init("醤油 大さじ2"), .init("1,5 kg de bœuf"), .init("Sel")])
        let plan = RecipeTranslationPlan(source)
        let ingredientTexts = plan.segments.filter { $0.id.hasPrefix("ingredient.") }.map(\.text)
        #expect(ingredientTexts == ["醤油 大さじ2", "1,5 kg de bœuf", "Sel"])
    }

    @Test func keepsTheOriginalWhereATranslationIsMissing() {
        let plan = RecipeTranslationPlan(Sample.italian)
        let translated = plan.apply(["title": "Spaghetti carbonara", "step.1": "   "])
        #expect(translated.title == "Spaghetti carbonara")
        #expect(translated.summary == Sample.italian.summary)
        #expect(translated.steps[1].text == Sample.italian.steps[1].text)
        #expect(translated.ingredients == Sample.italian.ingredients)
    }

    @Test func skipsBlankText() {
        let plan = RecipeTranslationPlan(RecipeText(title: "Soupe", summary: " "))
        #expect(plan.segments.map(\.id) == ["title"])
        #expect(plan.apply([:]).summary == " ")
    }
}

// MARK: - Showing the original

@Suite(.serialized)
struct RecipeTranslationStoreTests {
    private func makeRecipe(in context: ModelContext) -> Recipe {
        var draft = RecipeDraft(title: Sample.french.title)
        draft.summary = Sample.french.summary
        draft.ingredients = Sample.french.ingredients.map { RecipeDraft.Line($0.text, section: $0.section) }
        draft.steps = Sample.french.steps.map { RecipeDraft.Line($0.text, section: $0.section) }
        return Recipe.insert(from: draft, into: context)
    }

    private func translatedToEnglish(_ recipe: Recipe) -> (plan: RecipeTranslationPlan, text: RecipeText) {
        let plan = RecipeTranslationPlan(recipe.translationSource)
        let text = plan.apply(Dictionary(uniqueKeysWithValues: plan.segments.map { ($0.id, "EN " + $0.text) }))
        return (plan, text)
    }

    @Test func detectsOnceAndStoresTheLanguage() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let recipe = makeRecipe(in: context)
        #expect(recipe.originalLanguage == nil)
        recipe.detectLanguageIfNeeded()
        #expect(recipe.originalLanguage == "fr")

        let blank = Recipe(title: "Soup")
        context.insert(blank)
        blank.detectLanguageIfNeeded()
        #expect(blank.originalLanguage == nil)
    }

    @Test func showOriginalBringsBackTheImportedText() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let recipe = makeRecipe(in: context)
        let original = recipe.currentText

        let (plan, english) = translatedToEnglish(recipe)
        recipe.applyTranslation(english, of: plan.source, to: "en", in: context)
        #expect(recipe.isTranslated)
        #expect(recipe.translatedLanguage == "en")
        #expect(recipe.title == "EN Bœuf bourguignon")
        #expect(recipe.sortedSteps.map(\.section) == ["EN La veille", "EN Le jour même", "EN Le jour même"])
        #expect(!recipe.hasEditedTranslation)
        // Translating again starts from the original, not the translation.
        #expect(recipe.translationSource == original)

        recipe.showOriginal(in: context)
        #expect(!recipe.isTranslated)
        #expect(recipe.translationRecord == nil)
        #expect(recipe.keepsOriginalLanguage)
        #expect(recipe.currentText == original)
        #expect((recipe.ingredients ?? []).count == original.ingredients.count)
        #expect((recipe.steps ?? []).count == original.steps.count)
    }

    @Test func noticesEditsToATranslation() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let recipe = makeRecipe(in: context)
        let (plan, english) = translatedToEnglish(recipe)
        recipe.applyTranslation(english, of: plan.source, to: "en", in: context)

        recipe.sortedIngredients.first?.text = "1.5 kg stewing beef"
        #expect(recipe.hasEditedTranslation)

        recipe.showOriginal(in: context)
        #expect(recipe.sortedIngredients.first?.text == "1,5 kg de bœuf à braiser")
        #expect(!recipe.hasEditedTranslation)
    }
}

// MARK: - Foreign units

struct ForeignUnitTests {
    @Test(arguments: [
        ("2 EL Butter", "tbsp"),
        ("1 TL Salz", "tsp"),
        ("3 Esslöffel Zucker", "tbsp"),
        ("1 Teelöffel Zimt", "tsp"),
        ("1 cucchiaio di pepe nero", "tbsp"),
        ("2 cucchiai di olio", "tbsp"),
        ("1 cucchiaino di sale", "tsp"),
        ("2 cuillères à soupe de farine", "tbsp"),
        ("1 cuillère à café de sel", "tsp"),
        ("2 c. à s. d’huile", "tbsp"),
        ("1 c. à c. de cumin", "tsp"),
        ("4 cucharadas de aceite", "tbsp"),
        ("1 cucharadita de sal", "tsp"),
        ("1 大さじ", "tbsp"),
        ("1 小さじ", "tsp"),
        ("300グラム 鶏もも肉", "g"),
        ("500 gramos de patatas", "g"),
    ])
    func recognisesForeignUnits(line: String, unit: String) {
        #expect(IngredientParser.parse(line).unit == unit)
    }

    @Test func leavesWordsThatOnlyStartLikeAUnit() {
        #expect(IngredientParser.parse("2 elotes").unit == nil)
        #expect(IngredientParser.parse("4 Eier").unit == nil)
        #expect(IngredientParser.parse("2 tlayudas").unit == nil)
    }

    @Test func englishUnitsStillWork() {
        #expect(IngredientParser.parse("1 c milk").unit == "cup")
        #expect(IngredientParser.parse("1 T butter").unit == "tbsp")
        #expect(IngredientParser.parse("1 t salt").unit == "tsp")
        #expect(IngredientParser.parse("350g flour").unit == "g")
    }

    @Test func findsJapaneseUnitsWithoutASpace() {
        #expect(Units.foreignMatch(atStartOf: "大さじ2")?.unit == "tbsp")
        #expect(Units.foreignMatch(atStartOf: "小さじ1/2")?.unit == "tsp")
        #expect(Units.foreignMatch(atStartOf: "グラム鶏肉")?.length == 3)
    }

    @Test(arguments: [
        ("2 cuillères à soupe de farine", "30 ml de farine"),
        ("1 c. à c. de sel", "5 ml de sel"),
        ("2 EL Butter", "30 ml Butter"),
        ("1 cucharadita de sal", "5 ml de sal"),
    ])
    func convertsForeignSpoons(line: String, expected: String) {
        #expect(IngredientParser.parse(line).display(scaledBy: 1, in: .metric) == expected)
    }

    @Test func scalingKeepsTheForeignUnit() {
        #expect(IngredientParser.parse("2 EL Butter").scaled(by: 2) == "4 EL Butter")
    }

    @Test(arguments: [
        ("2 c. à s. de farine", "2", "c. à s.", "de farine"),
        ("2 cuillères à soupe de farine", "2", "cuillères à soupe", "de farine"),
        ("300グラム 鶏もも肉", "300", "グラム", "鶏もも肉"),
        ("2 EL Butter", "2", "EL", "Butter"),
    ])
    func editorSplitsForeignUnits(line: String, amount: String, unit: String, name: String) {
        #expect(IngredientParts(parsing: line) == IngredientParts(amount: amount, unit: unit, name: name))
    }
}
