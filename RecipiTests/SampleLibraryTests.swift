import Foundation
import RecipiKit
import SwiftData
import Testing
@testable import Recipi

/// The App Store screenshots start from the sample library, but run only on
/// demand (`AppStoreScreenshotTests`). These check it on every pull request.
@MainActor
struct SampleLibraryTests {
    @Test func seedsEveryRecipeWithAPhotoAndTags() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = container.mainContext
        SampleLibrary.seed(into: context)

        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        #expect(recipes.count == SampleLibrary.samples.count)
        for recipe in recipes {
            #expect(recipe.photoData != nil, "\(recipe.title) has no photo")
            #expect(!(recipe.tags ?? []).isEmpty, "\(recipe.title) has no tags")
            #expect(!recipe.sortedIngredients.isEmpty && !recipe.sortedSteps.isEmpty, "\(recipe.title) is empty")
        }

        // The screenshots scale this one from 2 servings and cook its five steps.
        let salmon = try #require(recipes.first { $0.title == "Miso Butter Salmon" })
        #expect(salmon.servings == 2)
        #expect(salmon.sortedSteps.count == 5)
        #expect(salmon.lastCookedAt != nil)

        let groceries = try context.fetch(FetchDescriptor<GroceryItem>())
        #expect(groceries.count == SampleLibrary.groceries.count)
        #expect(groceries.contains { $0.isChecked })
        #expect(groceries.contains { !$0.isChecked })
    }

    @Test func drawsADifferentPhotoForEachRecipe() throws {
        let photos = SampleLibrary.samples.compactMap { SamplePhoto.jpeg($0.photo) }
        #expect(photos.count == SampleLibrary.samples.count)
        #expect(Set(photos).count == photos.count)
        let size = try #require(RecipePhotoProcessor.pixelSize(of: photos[0]))
        #expect(size.width == SamplePhoto.width && size.height == SamplePhoto.height)
    }

    @Test func drawsTheSamePhotoEveryTime() {
        let style = SampleLibrary.samples[0].photo
        #expect(SamplePhoto.jpeg(style) == SamplePhoto.jpeg(style))
    }
}
