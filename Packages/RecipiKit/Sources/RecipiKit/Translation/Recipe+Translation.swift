import Foundation
import SwiftData

/// What `Recipe.translationRecord` holds while a translation is shown.
struct RecipeTranslationRecord: Codable, Equatable {
    /// The text as it was before translating, to bring back.
    var original: RecipeText
    /// The text as translated, to tell whether the person has edited it
    /// since.
    var translated: RecipeText
}

extension Recipe {
    /// The recipe's title, summary, ingredients and steps as shown now.
    public var currentText: RecipeText {
        RecipeText(
            title: title,
            summary: summary,
            ingredients: sortedIngredients.map { RecipeText.Line($0.text, section: $0.section) },
            steps: sortedSteps.map { RecipeText.Line($0.text, section: $0.section) }
        )
    }

    /// True while the recipe shows a translation.
    public var isTranslated: Bool { translatedLanguage != nil }

    /// The text to translate from: the original while a translation is
    /// shown, so translating again (say into another language) never
    /// translates a translation.
    public var translationSource: RecipeText {
        storedTranslation?.original ?? currentText
    }

    /// True when the translation shown has been edited since it was made,
    /// so going back to the original would lose those edits.
    public var hasEditedTranslation: Bool {
        guard isTranslated, let record = storedTranslation else { return false }
        return record.translated != currentText
    }

    /// Tells the recipe's language from its text, once. Recipes with only a
    /// few words are left to check again later.
    public func detectLanguageIfNeeded() {
        guard originalLanguage == nil else { return }
        let text = currentText
        guard text.languageSample.filter(\.isLetter).count >= 12 else { return }
        originalLanguage = RecipeLanguage.detect(text) ?? RecipeLanguage.undetermined
    }

    /// Shows `translated` in place of `original`, keeping `original` so
    /// `showOriginal(in:)` can bring it back. Sections are kept as they are
    /// in `translated`.
    public func applyTranslation(_ translated: RecipeText, of original: RecipeText, to language: String, in context: ModelContext) {
        setText(translated, in: context)
        // Stored as it reads back after saving (trimmed, blank lines
        // dropped), so an untouched translation never counts as edited.
        let record = RecipeTranslationRecord(original: original, translated: currentText)
        guard let data = try? JSONEncoder().encode(record) else {
            setText(original, in: context)
            return
        }
        translationRecord = data
        translatedLanguage = language
        keepsOriginalLanguage = false
    }

    /// Brings back the text from before translating and remembers that the
    /// person wants this recipe in its own language.
    public func showOriginal(in context: ModelContext) {
        if let record = storedTranslation {
            setText(record.original, in: context)
        }
        translationRecord = nil
        translatedLanguage = nil
        keepsOriginalLanguage = true
    }

    private var storedTranslation: RecipeTranslationRecord? {
        guard let translationRecord else { return nil }
        return try? JSONDecoder().decode(RecipeTranslationRecord.self, from: translationRecord)
    }

    private func setText(_ text: RecipeText, in context: ModelContext) {
        title = text.title
        summary = text.summary
        setIngredients(text.ingredients.map { RecipeDraft.Line($0.text, section: $0.section) }, in: context)
        setSteps(text.steps.map { RecipeDraft.Line($0.text, section: $0.section) }, in: context)
    }
}
