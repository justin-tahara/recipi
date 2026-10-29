import Foundation
import SwiftData
import Testing
@testable import RecipiKit

/// The editor's save path against a real (in-memory) SwiftData store.
@Suite(.serialized)
struct RecipeEditDraftStoreTests {
    private func makeRecipe(in context: ModelContext) -> Recipe {
        var draft = RecipeDraft(title: "Pasta with tomato sauce")
        draft.summary = "A weeknight pasta."
        draft.sourceURL = URL(string: "https://example.com/pasta")
        draft.author = "Sam Cook"
        draft.servings = 4
        draft.yieldText = "4 bowls"
        draft.prepTime = 600
        draft.cookTime = 1200
        draft.totalTime = 1800
        draft.ingredients = [
            .init("400 g spaghetti"),
            .init("2 tbsp olive oil", section: "For the sauce"),
            .init("1 (14 oz) can tomatoes", section: "For the sauce"),
            .init("Parmesan", section: "To serve"),
        ]
        draft.steps = [
            .init("Warm the oil.", section: "Make the sauce"),
            .init("Add the tomatoes.", section: "Make the sauce"),
            .init("Boil the pasta."),
        ]
        draft.tags = ["Dinner", "Quick"]
        let recipe = Recipe.insert(from: draft, into: context)
        recipe.notes = "Add chilli if you like."
        return recipe
    }

    private func lines(of ingredients: [Ingredient]) -> [RecipeDraft.Line] {
        ingredients.map { RecipeDraft.Line($0.text, section: $0.section) }
    }

    private func lines(of steps: [Step]) -> [RecipeDraft.Line] {
        steps.map { RecipeDraft.Line($0.text, section: $0.section) }
    }

    @Test func savingKeepsIngredientAndStepSections() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let recipe = makeRecipe(in: context)
        try context.save()
        let ingredientsBefore = lines(of: recipe.sortedIngredients)
        let stepsBefore = lines(of: recipe.sortedSteps)

        // Open the editor's copy and save it untouched.
        RecipeEditDraft(recipe).apply(to: recipe, in: context)
        try context.save()

        let saved = try #require(try context.fetch(FetchDescriptor<Recipe>()).first)
        #expect(lines(of: saved.sortedIngredients) == ingredientsBefore)
        #expect(lines(of: saved.sortedSteps) == stepsBefore)
        #expect(saved.sortedIngredients[1].section == "For the sauce")
        #expect(saved.sortedSteps[0].section == "Make the sauce")
        #expect(saved.sortedSteps[2].section == nil)
        // Rows were updated in place, so nothing is left behind.
        #expect(try context.fetchCount(FetchDescriptor<Ingredient>()) == 4)
        #expect(try context.fetchCount(FetchDescriptor<Step>()) == 3)
    }

    @Test func savingAnEditedDraftWritesEveryField() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let recipe = makeRecipe(in: context)
        try context.save()

        var draft = RecipeEditDraft(recipe)
        draft.title = "  Spaghetti al pomodoro "
        draft.summary = "Better than the jar."
        draft.sourceURLText = "example.org/spaghetti"
        draft.author = " "
        draft.servings = 2
        draft.yieldText = "2 plates"
        draft.prepTime = 300
        draft.cookTime = nil
        draft.totalTime = 900
        draft.photoData = Data([1, 2, 3])
        draft.notes = "Use San Marzano."
        draft.isFavorite = true
        // Move "To serve" and Parmesan above the sauce section.
        draft.ingredients.moveRows(fromOffsets: IndexSet([4, 5]), toOffset: 1)
        let basil = draft.ingredients.insertRow(after: draft.ingredients.last?.id)
        if let index = draft.ingredients.firstIndex(where: { $0.id == basil }) {
            draft.ingredients[index].text = "Basil leaves"
        }
        draft.steps.removeRow(draft.steps[4].id)
        draft.removeTag("quick")
        draft.addTag("dinner")
        draft.addTag("Italian")
        draft.apply(to: recipe, in: context)
        try context.save()

        let saved = try #require(try context.fetch(FetchDescriptor<Recipe>()).first)
        #expect(saved.title == "Spaghetti al pomodoro")
        #expect(saved.summary == "Better than the jar.")
        #expect(saved.sourceURL == URL(string: "https://example.org/spaghetti"))
        #expect(saved.author == nil)
        #expect(saved.servings == 2)
        #expect(saved.yieldText == "2 plates")
        #expect(saved.prepTime == 300)
        #expect(saved.cookTime == nil)
        #expect(saved.totalTime == 900)
        #expect(saved.photoData == Data([1, 2, 3]))
        #expect(saved.notes == "Use San Marzano.")
        #expect(saved.isFavorite)
        #expect(lines(of: saved.sortedIngredients) == [
            .init("400 g spaghetti"),
            .init("Parmesan", section: "To serve"),
            .init("2 tbsp olive oil", section: "For the sauce"),
            .init("1 (14 oz) can tomatoes", section: "For the sauce"),
            .init("Basil leaves", section: "For the sauce"),
        ])
        #expect(lines(of: saved.sortedSteps) == [
            .init("Warm the oil.", section: "Make the sauce"),
            .init("Add the tomatoes.", section: "Make the sauce"),
        ])
        #expect(saved.sortedTags.map(\.name) == ["Dinner", "Italian"])
        #expect(try context.fetchCount(FetchDescriptor<Ingredient>()) == 5)
        #expect(try context.fetchCount(FetchDescriptor<Step>()) == 2)
        // "dinner" matched the existing tag instead of making a second one.
        let tags = try context.fetch(FetchDescriptor<RecipiKit.Tag>())
        let dinnerTags = tags.filter { $0.name.lowercased() == "dinner" }
        #expect(dinnerTags.count == 1)
    }

    @Test func cancellingLeavesTheRecipeUnchanged() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let recipe = makeRecipe(in: context)
        try context.save()
        let updatedAt = recipe.updatedAt
        let ingredientsBefore = lines(of: recipe.sortedIngredients)
        let stepsBefore = lines(of: recipe.sortedSteps)

        var draft = RecipeEditDraft(recipe)
        let original = draft
        draft.title = "Something else"
        draft.ingredients.removeAll()
        draft.steps.moveRows(fromOffsets: IndexSet([0]), toOffset: draft.steps.count)
        draft.removeTag("Dinner")
        draft.isFavorite = true
        // Cancel throws the draft away without applying it.
        #expect(draft != original)

        let saved = try #require(try context.fetch(FetchDescriptor<Recipe>()).first)
        #expect(saved.title == "Pasta with tomato sauce")
        #expect(saved.isFavorite == false)
        #expect(saved.updatedAt == updatedAt)
        #expect(lines(of: saved.sortedIngredients) == ingredientsBefore)
        #expect(lines(of: saved.sortedSteps) == stepsBefore)
        #expect(saved.sortedTags.map(\.name) == ["Dinner", "Quick"])
        #expect(RecipeEditDraft(saved).equalsIgnoringRowIDs(original))
    }

    @Test func anUnreadableLinkKeepsTheOldOne() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let recipe = makeRecipe(in: context)

        var draft = RecipeEditDraft(recipe)
        draft.sourceURLText = "not a link"
        #expect(!draft.isSourceURLValid)
        draft.apply(to: recipe, in: context)
        #expect(recipe.sourceURL == URL(string: "https://example.com/pasta"))

        draft.sourceURLText = ""
        draft.apply(to: recipe, in: context)
        #expect(recipe.sourceURL == nil)
    }
}

struct RecipeEditDraftRowTests {
    @Test func rowsPutAHeadingWhereTheSectionChanges() {
        let rows = RecipeEditDraft.rows(from: [
            .init("Spaghetti"),
            .init("Oil", section: "Sauce"),
            .init("Tomatoes", section: "Sauce"),
            .init("Salt"),
        ])
        #expect(rows.map(\.kind) == [.item, .heading, .item, .item, .heading, .item])
        #expect(rows.map(\.text) == ["Spaghetti", "Sauce", "Oil", "Tomatoes", "", "Salt"])
        #expect(RecipeEditDraft.lines(from: rows) == [
            .init("Spaghetti"),
            .init("Oil", section: "Sauce"),
            .init("Tomatoes", section: "Sauce"),
            .init("Salt"),
        ])
    }

    @Test func linesDropBlankRowsAndEmptyHeadings() {
        let rows: [RecipeEditDraft.Row] = [.heading("Unused"), .heading(" Dough "), .item(" Flour "), .item("  "), .heading("Empty")]
        #expect(RecipeEditDraft.lines(from: rows) == [.init("Flour", section: "Dough")])
    }

    @Test func returnAtTheEndAddsAnEmptyRowBelow() {
        var rows: [RecipeEditDraft.Row] = [.item("Flour\n"), .item("Sugar")]
        let id = rows.splitLines(at: rows[0].id)
        #expect(rows.map(\.text) == ["Flour", "", "Sugar"])
        #expect(id == rows[1].id)
    }

    @Test func pastingSeveralLinesMakesARowEach() {
        var rows: [RecipeEditDraft.Row] = [.heading("Sauce\n2 tbsp oil\n\n1 can tomatoes")]
        let id = rows.splitLines(at: rows[0].id)
        #expect(rows.map(\.text) == ["Sauce", "2 tbsp oil", "1 can tomatoes"])
        #expect(rows.map(\.kind) == [.heading, .item, .item])
        #expect(id == rows[2].id)
        #expect(rows.splitLines(at: rows[1].id) == nil)
    }

    @Test func togglingKindTurnsAnImportedHeadingIntoOne() {
        var rows: [RecipeEditDraft.Row] = [.item("For the sauce:"), .item("Oil")]
        rows.toggleKind(of: rows[0].id)
        #expect(rows[0].kind == .heading)
        #expect(rows[0].text == "For the sauce")
        rows.toggleKind(of: rows[0].id)
        #expect(rows[0].kind == .item)
    }

    @Test func movingRowsMatchesListDragToReorder() {
        let start: [RecipeEditDraft.Row] = ["a", "b", "c", "d"].map { .item($0) }

        var down = start
        down.moveRows(fromOffsets: IndexSet([0]), toOffset: 3)
        #expect(down.map(\.text) == ["b", "c", "a", "d"])

        var up = start
        up.moveRows(fromOffsets: IndexSet([3]), toOffset: 0)
        #expect(up.map(\.text) == ["d", "a", "b", "c"])

        var several = start
        several.moveRows(fromOffsets: IndexSet([0, 2]), toOffset: 4)
        #expect(several.map(\.text) == ["b", "d", "a", "c"])

        var stepped = start
        stepped.moveRow(stepped[1].id, by: 1)
        stepped.moveRow(stepped[0].id, by: -1)
        #expect(stepped.map(\.text) == ["a", "c", "b", "d"])
    }
}

struct RecipeEditDraftTagTests {
    @Test func addingATagReusesTheExistingSpelling() {
        var draft = RecipeEditDraft()
        let addedFirst = draft.addTag(" vegetarian ", existing: ["Vegetarian", "Dinner"])
        #expect(addedFirst)
        let addedDuplicate = draft.addTag("VEGETARIAN")
        #expect(!addedDuplicate)
        let addedBlank = draft.addTag("   ")
        #expect(!addedBlank)
        #expect(draft.tags == ["Vegetarian"])
    }

    @Test func suggestionsPreferPrefixesAndSkipChosenTags() {
        var draft = RecipeEditDraft()
        draft.addTag("Dinner")
        let existing = ["Breakfast", "dinner", "Soup", "Weeknight dinner", "Dips", "Side dish"]
        #expect(draft.tagSuggestions(for: "di", from: existing) == ["Dips", "Side dish", "Weeknight dinner"])
        #expect(draft.tagSuggestions(for: "", from: existing, limit: 2) == ["Breakfast", "Dips"])
    }
}

struct IngredientPartsTests {
    @Test(arguments: [
        ("1 1/2 cups flour, sifted", "1 1/2", "cups", "flour, sifted"),
        ("350g flour", "350", "g", "flour"),
        ("2-3 cloves garlic", "2-3", "cloves", "garlic"),
        ("1 tbsp. butter", "1", "tbsp.", "butter"),
        ("3 eggs", "3", "", "eggs"),
        ("1 (14 oz) can tomatoes", "1", "", "(14 oz) can tomatoes"),
        ("Salt and pepper to taste", "", "", "Salt and pepper to taste"),
    ])
    func splitsALine(line: String, amount: String, unit: String, name: String) {
        let parts = IngredientParts(parsing: line)
        #expect(parts == IngredientParts(amount: amount, unit: unit, name: name))
    }

    @Test func joiningGivesTheLineBack() {
        #expect(IngredientParts(parsing: "1 1/2 cups flour").line == "1 1/2 cups flour")
        var parts = IngredientParts(parsing: "2 cups milk")
        parts.amount = "3"
        parts.unit = ""
        #expect(parts.line == "3 milk")
    }
}

extension RecipeEditDraft {
    /// Two drafts of the same recipe get fresh row ids, so compare the rest.
    fileprivate func equalsIgnoringRowIDs(_ other: RecipeEditDraft) -> Bool {
        var mine = self
        var theirs = other
        mine.ingredients = []
        mine.steps = []
        theirs.ingredients = []
        theirs.steps = []
        return mine == theirs
            && ingredients.map(\.kind) == other.ingredients.map(\.kind)
            && ingredients.map(\.text) == other.ingredients.map(\.text)
            && steps.map(\.kind) == other.steps.map(\.kind)
            && steps.map(\.text) == other.steps.map(\.text)
    }
}
