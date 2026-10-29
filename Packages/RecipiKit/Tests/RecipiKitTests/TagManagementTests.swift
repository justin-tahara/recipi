import Foundation
import SwiftData
import Testing
@testable import RecipiKit

/// Tag kinds, renaming, merging and deleting against a real (in-memory)
/// SwiftData store.
@Suite(.serialized)
struct TagManagementTests {
    private func recipe(_ title: String, tags: [String], in context: ModelContext) -> Recipe {
        let recipe = Recipe(title: title)
        context.insert(recipe)
        recipe.tags = tags.compactMap { RecipiKit.Tag.findOrCreate(named: $0, in: context) }
        return recipe
    }

    private func allTags(_ context: ModelContext) throws -> [RecipiKit.Tag] {
        try context.fetch(FetchDescriptor<RecipiKit.Tag>(sortBy: [SortDescriptor(\.name)]))
    }

    @Test func importAppliesAutoTagsWithKinds() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        var draft = RecipeDraft(title: "Spaghetti alla carbonara")
        draft.tags = ["Primi piatti", "italiano", "pasta", "guanciale", "pecorino", "uova", "roma"]
        draft.totalTime = 1_500
        draft.ingredients = [.init("320 g spaghetti")]
        let recipe = Recipe.insert(from: draft, into: context)
        try context.save()

        #expect(recipe.sortedTags.map(\.name) == ["Dinner", "guanciale", "Italian", "pasta", "pecorino", "Quick"])
        let italian = try #require(recipe.sortedTags.first { $0.name == "Italian" })
        #expect(italian.kindRaw == "cuisine")
        #expect(italian.kind == .cuisine)
        #expect(recipe.sortedTags.first { $0.name == "pasta" }?.kind == nil)
    }

    @Test func importReusesExistingTagsWhateverTheirCase() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        _ = recipe("Old favourite", tags: ["dinner"], in: context)
        var draft = RecipeDraft(title: "New one")
        draft.tags = ["Main Course"]
        draft.steps = [.init("Cook.")]
        let imported = Recipe.insert(from: draft, into: context)
        try context.save()

        #expect(imported.sortedTags.map(\.name) == ["dinner"])
        #expect(try allTags(context).count == 1)
    }

    @Test func kindComesFromTheVocabularyUnlessSet() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let tag = try #require(RecipiKit.Tag.findOrCreate(named: "japonais", in: context))
        #expect(tag.kindRaw == nil)
        #expect(tag.kind == .cuisine)

        tag.kind = nil
        #expect(tag.kindRaw == "none")
        #expect(tag.kind == nil)

        let own = try #require(RecipiKit.Tag.findOrCreate(named: "Nonna's", in: context))
        #expect(own.kind == nil)
        own.kind = .cuisine
        #expect(own.kind == .cuisine)
        // An import doesn't overwrite a kind the person chose.
        _ = RecipiKit.Tag.findOrCreate(named: "japonais", kind: .cuisine, in: context)
        #expect(tag.kind == nil)
    }

    @Test func renamingKeepsRecipesAndKind() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let carbonara = recipe("Carbonara", tags: ["Italian"], in: context)
        try context.save()
        let tag = try #require(carbonara.tags?.first)

        #expect(tag.rename(to: "  Nonna's  ", in: context) == .renamed)
        try context.save()
        #expect(carbonara.sortedTags.map(\.name) == ["Nonna's"])
        #expect(tag.kind == .cuisine)
        #expect(tag.rename(to: "Nonna's", in: context) == .unchanged)
        #expect(tag.rename(to: "   ", in: context) == .invalid)
        #expect(tag.rename(to: "nonna's", in: context) == .renamed, "Changing only the case is a rename")
    }

    @Test func renamingToAnotherTagsNameMergesThem() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let soup = recipe("Soup", tags: ["Veggie"], in: context)
        let salad = recipe("Salad", tags: ["Veggie", "Vegetarian"], in: context)
        let stew = recipe("Stew", tags: ["Vegetarian"], in: context)
        try context.save()
        let veggie = try #require(soup.tags?.first)
        let vegetarian = try #require(stew.tags?.first)
        veggie.colorOverride = "green"

        #expect(veggie.rename(to: "vegetarian", in: context) == .merged(into: vegetarian))
        try context.save()

        #expect(try allTags(context).map(\.name) == ["Vegetarian"])
        #expect(soup.sortedTags.map(\.name) == ["Vegetarian"])
        #expect(salad.sortedTags.map(\.name) == ["Vegetarian"], "A recipe with both keeps one")
        #expect(stew.sortedTags.map(\.name) == ["Vegetarian"])
        #expect(vegetarian.recipes?.count == 3)
        #expect(vegetarian.colorOverride == "green", "The merged tag takes a color it didn't have")
    }

    @Test func deletingATagKeepsItsRecipes() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let soup = recipe("Soup", tags: ["Winter", "Dinner"], in: context)
        try context.save()
        let winter = try #require(soup.sortedTags.last)
        #expect(winter.name == "Winter")

        winter.delete(in: context)
        try context.save()
        #expect(soup.sortedTags.map(\.name) == ["Dinner"])
        #expect(try allTags(context).map(\.name) == ["Dinner"])
        #expect(try context.fetchCount(FetchDescriptor<Recipe>()) == 1)
    }

    @Test func facetsCarryKinds() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let soup = recipe("Miso soup", tags: ["和食", "Weeknight"], in: context)
        let facets = soup.tagFacets.sorted { $0.name < $1.name }
        #expect(facets == [TagFacet(name: "Weeknight"), TagFacet(name: "和食", kind: .cuisine)])
        #expect(TagFilter(selection: [TagFacet(name: "Asian", kind: .cuisine)]).matches(soup.tagFacets))
    }
}
