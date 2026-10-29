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

    /// Every time it was cooked. See CookLog.swift.
    @Relationship(deleteRule: .cascade, inverse: \CookLog.recipe)
    public var cookLogs: [CookLog]? = []
    /// The newest `cookLogs` date, stored so the Library can sort by it.
    public var lastCookedAt: Date?

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

    /// Replaces the ingredient list with these lines, keeping each line's
    /// section heading. Blank lines are skipped. Existing ingredients are
    /// updated in place where they can be, so an edit doesn't delete and
    /// re-create every row in iCloud.
    public func setIngredients(_ lines: [RecipeDraft.Line], in context: ModelContext) {
        let cleaned = lines.cleanedForStorage()
        var existing = sortedIngredients
        var updated: [Ingredient] = []
        for (index, line) in cleaned.enumerated() {
            if existing.isEmpty {
                updated.append(Ingredient(text: line.text, order: index, section: line.section))
            } else {
                let ingredient = existing.removeFirst()
                ingredient.text = line.text
                ingredient.order = index
                ingredient.section = line.section
                updated.append(ingredient)
            }
        }
        ingredients = updated
        for leftover in existing { context.delete(leftover) }
    }

    /// Replaces the method with these lines, keeping each line's section
    /// heading. Works like `setIngredients(_:in:)`.
    public func setSteps(_ lines: [RecipeDraft.Line], in context: ModelContext) {
        let cleaned = lines.cleanedForStorage()
        var existing = sortedSteps
        var updated: [Step] = []
        for (index, line) in cleaned.enumerated() {
            if existing.isEmpty {
                updated.append(Step(text: line.text, order: index, section: line.section))
            } else {
                let step = existing.removeFirst()
                step.text = line.text
                step.order = index
                step.section = line.section
                updated.append(step)
            }
        }
        steps = updated
        for leftover in existing { context.delete(leftover) }
    }
}

extension [RecipeDraft.Line] {
    /// Trims each line and its section, drops empty lines, and turns a blank
    /// section into no section.
    func cleanedForStorage() -> [RecipeDraft.Line] {
        compactMap { line -> RecipeDraft.Line? in
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let section = line.section?.trimmingCharacters(in: .whitespacesAndNewlines)
            return RecipeDraft.Line(text, section: section?.isEmpty == false ? section : nil)
        }
    }
}

extension [String] {
    func cleanedLines() -> [String] {
        map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
