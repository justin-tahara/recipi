import Foundation
import SwiftData

extension Recipe {
    /// Inserts a new recipe built from an imported draft.
    @discardableResult
    public static func insert(from draft: RecipeDraft, photoData: Data? = nil, into context: ModelContext) -> Recipe {
        let recipe = Recipe(title: draft.title)
        // Insert before setting relationships, which SwiftData expects.
        context.insert(recipe)

        recipe.summary = draft.summary
        recipe.sourceURL = draft.sourceURL
        recipe.author = draft.author
        recipe.servings = draft.servings
        recipe.yieldText = draft.yieldText
        recipe.prepTime = draft.prepTime
        recipe.cookTime = draft.cookTime
        recipe.totalTime = draft.totalTime
        recipe.photoData = photoData

        recipe.ingredients = draft.ingredients.enumerated().map { index, line in
            Ingredient(text: line.text, order: index, section: line.section)
        }
        recipe.steps = draft.steps.enumerated().map { index, line in
            Step(text: line.text, order: index, section: line.section)
        }
        recipe.tags = draft.tags.compactMap { Tag.findOrCreate(named: $0, in: context) }
        return recipe
    }
}
