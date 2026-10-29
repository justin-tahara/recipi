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
        // The page's categories and keywords, tidied onto the tag
        // vocabulary, plus traits read from its nutrition and times.
        var seen = Set<PersistentIdentifier>()
        recipe.tags = AutoTagger.tags(for: draft).compactMap { autoTag in
            guard let tag = Tag.findOrCreate(named: autoTag.name, kind: autoTag.kind, in: context),
                  seen.insert(tag.persistentModelID).inserted else { return nil }
            return tag
        }
        return recipe
    }
}
