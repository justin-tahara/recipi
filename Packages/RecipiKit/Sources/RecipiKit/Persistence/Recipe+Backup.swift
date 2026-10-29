import Foundation
import SwiftData

extension Recipe {
    /// The recipe's stable ID, giving it one first if it was made before
    /// recipes had IDs. Save the context afterwards to keep it.
    @discardableResult
    public func ensureUUID() -> UUID {
        if let uuid { return uuid }
        let new = UUID()
        uuid = new
        return new
    }
}

extension BackupRecipe {
    /// A snapshot of `recipe`. Doesn't change the recipe: one without an ID
    /// gets a new one here only. Use `snapshots(of:)` for a backup.
    /// `includingPhotos: false` leaves out the recipe's and the cooks'
    /// photos, which saves reading them when they won't be written.
    public init(_ recipe: Recipe, includingPhotos: Bool = true) {
        self.init(
            id: recipe.uuid ?? UUID(),
            title: recipe.title,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt
        )
        summary = recipe.summary
        sourceURL = recipe.sourceURL
        author = recipe.author
        servings = recipe.servings
        yieldText = recipe.yieldText
        prepTime = recipe.prepTime
        cookTime = recipe.cookTime
        totalTime = recipe.totalTime
        notes = recipe.notes
        isFavorite = recipe.isFavorite
        ingredients = recipe.sortedIngredients.map { RecipeDraft.Line($0.text, section: $0.section) }
        steps = recipe.sortedSteps.map { RecipeDraft.Line($0.text, section: $0.section) }
        tags = recipe.sortedTags.map(\.name)
        photoData = includingPhotos ? recipe.photoData : nil
        cookLog = recipe.sortedCookLogs.map { log in
            BackupCook(cookedAt: log.cookedAt, note: log.note, photoData: includingPhotos ? log.photoData : nil)
        }
        originalLanguage = recipe.originalLanguage
        translatedLanguage = recipe.translatedLanguage
        keepsOriginalLanguage = recipe.keepsOriginalLanguage
        // A record that can't be read counts as none, as it does for
        // "Show original" itself.
        translation = recipe.translationRecord
            .flatMap { try? JSONDecoder().decode(RecipeTranslationRecord.self, from: $0) }
            .map { BackupTranslation(original: $0.original, translated: $0.translated) }
    }

    /// Snapshots for a backup. Gives a stable ID to each recipe that has
    /// none, or that shares one with another recipe (two devices can both
    /// assign an ID to the same older recipe before they sync), so every
    /// snapshot's `id` is unique. Save the context afterwards so the IDs
    /// stay the same in the next backup.
    public static func snapshots(of recipes: [Recipe]) -> [BackupRecipe] {
        var seen = Set<UUID>()
        return recipes.map { recipe in
            if !seen.insert(recipe.ensureUUID()).inserted {
                let replacement = UUID()
                recipe.uuid = replacement
                seen.insert(replacement)
            }
            return BackupRecipe(recipe)
        }
    }
}

/// How a restore went.
public struct RestoreSummary: Sendable, Equatable {
    /// Recipes added to the library.
    public var restored: Int
    /// Recipes left out because the library already had them (same ID or
    /// same source link), or the backup listed them twice.
    public var skippedDuplicates: Int

    public init(restored: Int, skippedDuplicates: Int) {
        self.restored = restored
        self.skippedDuplicates = skippedDuplicates
    }
}

extension RecipiBackup {
    /// Adds the recipes the library doesn't have yet and saves. A recipe
    /// counts as already there when one has the same ID or the same source
    /// link. Existing recipes are never changed.
    @discardableResult
    public static func restore(_ backups: [BackupRecipe], into context: ModelContext) throws -> RestoreSummary {
        let existing = try context.fetch(FetchDescriptor<Recipe>())
        var knownIDs = Set(existing.compactMap(\.uuid))
        var knownSources = Set(existing.compactMap { recipe in recipe.sourceURL.map { sourceKey($0) } })

        var summary = RestoreSummary(restored: 0, skippedDuplicates: 0)
        for backup in backups {
            let source = backup.sourceURL.map { sourceKey($0) }
            let isKnownSource = source.map { knownSources.contains($0) } ?? false
            if knownIDs.contains(backup.id) || isKnownSource {
                summary.skippedDuplicates += 1
                continue
            }
            try Recipe.insert(from: backup, into: context)
            knownIDs.insert(backup.id)
            if let source { knownSources.insert(source) }
            summary.restored += 1
        }
        if context.hasChanges {
            try context.save()
        }
        return summary
    }

    /// Links that differ only in a trailing slash or the host's case are
    /// the same recipe.
    static func sourceKey(_ url: URL) -> String {
        var key = url.absoluteString
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            let host = components.host?.lowercased()
            let scheme = components.scheme?.lowercased()
            components.host = host
            components.scheme = scheme
            key = components.string ?? key
        }
        while key.hasSuffix("/") { key.removeLast() }
        return key
    }
}

extension Recipe {
    /// Inserts a recipe from a backup exactly as it was saved: same ID,
    /// dates, favorite, section headings, cook history and translation.
    @discardableResult
    static func insert(from backup: BackupRecipe, into context: ModelContext) throws -> Recipe {
        let recipe = Recipe(title: backup.title)
        // Insert before setting relationships, which SwiftData expects.
        context.insert(recipe)

        recipe.uuid = backup.id
        recipe.summary = backup.summary
        recipe.sourceURL = backup.sourceURL
        recipe.author = backup.author
        recipe.servings = backup.servings
        recipe.yieldText = backup.yieldText
        recipe.prepTime = backup.prepTime
        recipe.cookTime = backup.cookTime
        recipe.totalTime = backup.totalTime
        recipe.photoData = backup.photoData
        recipe.notes = backup.notes
        recipe.isFavorite = backup.isFavorite
        recipe.createdAt = backup.createdAt
        recipe.updatedAt = backup.updatedAt

        recipe.ingredients = backup.ingredients.enumerated().map { index, line in
            Ingredient(text: line.text, order: index, section: line.section)
        }
        recipe.steps = backup.steps.enumerated().map { index, line in
            Step(text: line.text, order: index, section: line.section)
        }
        var tags: [Tag] = []
        for name in backup.tags {
            guard let tag = Tag.findOrCreate(named: name, in: context),
                  !tags.contains(where: { $0 === tag }) else { continue }
            tags.append(tag)
        }
        recipe.tags = tags

        let cooks = backup.cookLog.map { cook in
            CookLog(cookedAt: cook.cookedAt, photoData: cook.photoData, note: cook.note)
        }
        for cook in cooks { context.insert(cook) }
        recipe.cookLogs = cooks
        recipe.refreshLastCooked()

        recipe.originalLanguage = backup.originalLanguage
        recipe.translatedLanguage = backup.translatedLanguage
        recipe.keepsOriginalLanguage = backup.keepsOriginalLanguage
        if let translation = backup.translation {
            let record = RecipeTranslationRecord(original: translation.original, translated: translation.translated)
            recipe.translationRecord = try JSONEncoder().encode(record)
        }
        return recipe
    }
}
