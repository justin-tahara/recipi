import Foundation
import SwiftData

// CloudKit-backed SwiftData models have rules the compiler won't catch:
// every stored property needs a default value or must be optional, every
// relationship must be optional, and @Attribute(.unique) is not allowed.
// Breaking any of them makes sync fail at runtime, so keep to them here.

@Model
public final class Recipe {
    public var title: String = ""
    public var summary: String = ""
    public var sourceURL: URL?
    public var author: String?

    /// How many servings the ingredient amounts are written for, if known.
    public var servings: Int?
    /// The yield as the source wrote it, e.g. "Makes 24 cookies".
    public var yieldText: String?

    public var prepTime: TimeInterval?
    public var cookTime: TimeInterval?
    public var totalTime: TimeInterval?

    @Attribute(.externalStorage)
    public var photoData: Data?

    public var notes: String = ""
    public var isFavorite: Bool = false
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    public var ingredients: [Ingredient]? = []

    @Relationship(deleteRule: .cascade, inverse: \Step.recipe)
    public var steps: [Step]? = []

    @Relationship(inverse: \Tag.recipes)
    public var tags: [Tag]? = []

    public init(title: String = "") {
        self.title = title
    }
}

extension Recipe {
    public var sortedIngredients: [Ingredient] {
        (ingredients ?? []).sorted { $0.order < $1.order }
    }

    public var sortedSteps: [Step] {
        (steps ?? []).sorted { $0.order < $1.order }
    }

    public var sortedTags: [Tag] {
        (tags ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Replaces the ingredient list with one ingredient per non-empty line.
    public func setIngredients(_ lines: [String], in context: ModelContext) {
        for ingredient in ingredients ?? [] { context.delete(ingredient) }
        ingredients = lines.cleanedLines().enumerated().map { index, line in
            Ingredient(text: line, order: index)
        }
    }

    /// Replaces the method with one step per non-empty line.
    public func setSteps(_ lines: [String], in context: ModelContext) {
        for step in steps ?? [] { context.delete(step) }
        steps = lines.cleanedLines().enumerated().map { index, line in
            Step(text: line, order: index)
        }
    }
}

extension [String] {
    func cleanedLines() -> [String] {
        map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
