import Foundation

/// A tag to put on an imported recipe, with its kind when it's one of the
/// vocabulary's.
public struct AutoTag: Sendable, Hashable {
    public var name: String
    public var kind: TagKind?

    public init(_ name: String, kind: TagKind? = nil) {
        self.name = name
        self.kind = kind
    }
}

/// Turns what a page says about a recipe into tidy tags, on device: the
/// page's categories, cuisines and keywords mapped onto the vocabulary
/// ("italiano" becomes "Italian"), its diets, traits worked out from its
/// nutrition and times, and at most a few of its other keywords. They're
/// ordinary tags; a person can remove any of them.
public enum AutoTagger {
    /// The defaults issue #16 settled on. Nutrition is per serving, as
    /// schema.org gives it.
    public enum Thresholds {
        /// "High protein": at least this many grams of protein per serving.
        public static let highProteinGrams: Double = 25
        /// "Light": at most this many kilocalories per serving.
        public static let lightCalories: Double = 450
        /// "Quick": ready in at most this long, in seconds.
        public static let quickTime: TimeInterval = 30 * 60
    }

    /// Keywords that aren't in the vocabulary are kept, up to this many.
    /// Sites stuff keywords for search engines; a few are useful, a dozen
    /// are noise.
    public static let maxFreeFormTags = 3
    /// A kept keyword is at most this long and this many words.
    static let maxFreeFormLength = 24
    static let maxFreeFormWords = 3

    public static func tags(for draft: RecipeDraft) -> [AutoTag] {
        var vocabulary: [VocabularyTerm] = []
        var freeForm: [String] = []

        for value in draft.tags {
            if let terms = TagVocabulary.terms(in: value) {
                for term in terms where !vocabulary.contains(term) {
                    vocabulary.append(term)
                }
            } else if freeForm.count < maxFreeFormTags, isUsefulKeyword(value, title: draft.title) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = TagVocabulary.normalized(trimmed)
                if !freeForm.contains(where: { TagVocabulary.normalized($0) == key }) {
                    freeForm.append(trimmed)
                }
            }
        }

        for diet in draft.diets {
            if let term = TagVocabulary.term(matching: diet), term.kind == .diet || term.kind == .trait,
               !vocabulary.contains(term) {
                vocabulary.append(term)
            }
        }

        vocabulary = applyingMeasuredTraits(to: vocabulary, draft: draft)

        var result = vocabulary.map { AutoTag($0.name, kind: $0.kind) }
        for keyword in freeForm where !result.contains(where: { $0.name.caseInsensitiveCompare(keyword) == .orderedSame }) {
            result.append(AutoTag(keyword))
        }
        return result
    }

    // MARK: - Traits

    /// Adds or removes "High protein", "Light" and "Quick" from what the
    /// recipe's numbers say. When a number is known it decides, whatever the
    /// page's keywords claimed; when it isn't, a keyword stands, and a
    /// conservative guess from the title may add the trait.
    static func applyingMeasuredTraits(to terms: [VocabularyTerm], draft: RecipeDraft) -> [VocabularyTerm] {
        var terms = terms
        let names = Set(terms.map(\.name))

        func set(_ name: String, _ isOn: Bool?) {
            guard let isOn, let term = TagVocabulary.term(named: name) else { return }
            if isOn {
                if !terms.contains(term) { terms.append(term) }
            } else {
                terms.removeAll { $0 == term }
            }
        }

        set("High protein", isHighProtein(draft))
        let isDessertOrDrink = names.contains("Dessert") || names.contains("Drink")
        set("Light", isLight(draft, isDessertOrDrink: isDessertOrDrink))
        set("Quick", isQuick(draft))
        return terms
    }

    /// True or false when the numbers say; nil when they're unknown. A title
    /// like "Protein pancakes" counts as true when there's no nutrition.
    static func isHighProtein(_ draft: RecipeDraft) -> Bool? {
        if let protein = draft.nutrition?.proteinGrams {
            return protein >= Thresholds.highProteinGrams
        }
        return titleWords(draft).contains("protein") ? true : nil
    }

    /// Light is about meals, so desserts and drinks aren't tagged light by
    /// their calories. Without calories, a salad is light, unless it's one of
    /// the heavy ones (potato, pasta, taco…).
    static func isLight(_ draft: RecipeDraft, isDessertOrDrink: Bool) -> Bool? {
        if let calories = draft.nutrition?.calories {
            return isDessertOrDrink ? false : calories <= Thresholds.lightCalories
        }
        guard !isDessertOrDrink else { return nil }
        let words = titleWords(draft)
        let title = draft.title.lowercased()
        let isSalad = !words.isDisjoint(with: saladWords) || title.contains("サラダ")
        guard isSalad, words.isDisjoint(with: heavySaladWords) else { return nil }
        return true
    }

    /// Total time, or prep plus cook when both are given.
    static func isQuick(_ draft: RecipeDraft) -> Bool? {
        let time: TimeInterval?
        if let total = draft.totalTime, total > 0 {
            time = total
        } else if let prep = draft.prepTime, let cook = draft.cookTime, prep + cook > 0 {
            time = prep + cook
        } else {
            time = nil
        }
        return time.map { $0 <= Thresholds.quickTime }
    }

    static let saladWords: Set<String> = ["salad", "salads", "salade", "insalata", "ensalada", "salat", "salada", "slaw"]
    static let heavySaladWords: Set<String> = [
        "potato", "potatoes", "pasta", "macaroni", "mac", "taco", "dressing", "ambrosia", "snickers", "fluff",
        "kartoffelsalat", "nudelsalat",
    ]

    private static func titleWords(_ draft: RecipeDraft) -> Set<String> {
        Set(TagVocabulary.normalized(draft.title).split(separator: " ").map(String.init))
    }

    // MARK: - Keywords

    /// False for keywords that make poor tags: long phrases, links, numbers,
    /// search-engine phrases ("easy pancake recipe", "how to make pancakes")
    /// and the recipe's own title.
    static func isUsefulKeyword(_ raw: String, title: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2, value.count <= maxFreeFormLength else { return false }
        if value.contains(where: { $0.isNumber || "/@#|<>{}[]=\\".contains($0) }) { return false }
        let lowered = value.lowercased()
        if lowered.contains("http") || lowered.contains("www.") || lowered.contains(".com") { return false }

        let key = TagVocabulary.normalized(value)
        let words = key.split(separator: " ")
        guard !words.isEmpty, words.count <= maxFreeFormWords else { return false }
        if words.contains(where: { $0 == "recipe" || $0 == "recipes" }) || key.hasPrefix("how to") { return false }
        // Only filler ("easy", "best") says nothing.
        if words.count > 1, words.allSatisfy({ TagVocabulary.fillerWords.contains(String($0)) }) {
            return false
        }
        if key == TagVocabulary.normalized(title) { return false }
        return true
    }
}
