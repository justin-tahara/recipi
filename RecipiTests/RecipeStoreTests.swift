import Foundation
import RecipiKit
import SwiftData
import Testing
@testable import Recipi

/// Saves through the same code the import sheet and share extension use,
/// into the in-memory store the app opens under test.
@MainActor
struct RecipeStoreTests {
    @Test func savesADraftAndReadsItBack() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = container.mainContext

        var draft = RecipeDraft(title: "Weeknight Dal")
        draft.servings = 4
        draft.totalTime = 1_800
        draft.ingredients = [.init("1 cup red lentils"), .init("2 tbsp ghee", section: "Tadka")]
        draft.steps = [.init("Simmer the lentils until soft."), .init("Pour the hot ghee over the dal.", section: "Tadka")]
        draft.tags = ["Vegetarian", "Dinner"]
        Recipe.insert(from: draft, into: context)
        try context.save()

        let recipes = try context.fetch(FetchDescriptor(predicate: #Predicate<Recipe> { $0.title == "Weeknight Dal" }))
        #expect(recipes.count == 1)
        let recipe = try #require(recipes.first)
        #expect(recipe.title == "Weeknight Dal")
        #expect(recipe.servings == 4)
        #expect(recipe.totalTime == 1_800)
        #expect(recipe.sortedIngredients.map(\.text) == ["1 cup red lentils", "2 tbsp ghee"])
        #expect(recipe.sortedIngredients.map(\.section) == [nil, "Tadka"])
        #expect(recipe.sortedSteps.map(\.text) == ["Simmer the lentils until soft.", "Pour the hot ghee over the dal."])
        // 30 minutes in all, so saving also tags it Quick (see AutoTagger).
        #expect(recipe.sortedTags.map(\.name) == ["Dinner", "Quick", "Vegetarian"])
    }

    /// CloudKit rules out unique constraints, so tags are deduped by hand.
    @Test func reusesATagThatIsAlreadySaved() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = container.mainContext

        var first = RecipeDraft(title: "Dal")
        first.tags = ["Batch cooking"]
        Recipe.insert(from: first, into: context)
        try context.save()

        var second = RecipeDraft(title: "Curry")
        second.tags = ["batch cooking"]
        Recipe.insert(from: second, into: context)
        try context.save()

        // Spelled out because Swift Testing also has a `Tag` type.
        let tags = try context.fetch(FetchDescriptor<RecipiKit.Tag>())
            .filter { $0.name.lowercased() == "batch cooking" }
        #expect(tags.map(\.name) == ["Batch cooking"])
        #expect(tags.first?.recipes?.count == 2)
    }
}
