import Foundation

/// The words of a recipe that get translated: title, summary, ingredients
/// and steps, each line with its section heading. Plain values, so a copy
/// can be kept as the original while a translation is shown.
public struct RecipeText: Codable, Sendable, Equatable {
    public struct Line: Codable, Sendable, Equatable {
        public var text: String
        public var section: String?

        public init(_ text: String, section: String? = nil) {
            self.text = text
            self.section = section
        }
    }

    public var title: String
    public var summary: String
    public var ingredients: [Line]
    public var steps: [Line]

    public init(title: String = "", summary: String = "", ingredients: [Line] = [], steps: [Line] = []) {
        self.title = title
        self.summary = summary
        self.ingredients = ingredients
        self.steps = steps
    }

    /// Everything a person reads, one piece per line, for telling which
    /// language the recipe is in.
    public var languageSample: String {
        var pieces = [title, summary]
        var headings: [String] = []
        for line in ingredients + steps {
            if let section = line.section, !headings.contains(section) { headings.append(section) }
        }
        pieces += headings
        pieces += ingredients.map(\.text)
        pieces += steps.map(\.text)
        return pieces.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

/// Turns a recipe into the pieces of text to send to a translator, and the
/// translated pieces back into a recipe.
///
/// - Each section heading is translated once, so every line under it keeps
///   the same (translated) heading and the sections stay grouped.
/// - An ingredient's leading amount ("2", "1 1/2", "350g") is kept exactly
///   as written and only the words after it are translated, so scaling and
///   unit conversion read the same amount after translation.
/// - A piece the translator didn't return keeps its original text.
public struct RecipeTranslationPlan: Sendable, Equatable {
    /// One piece of text to translate, with an id to match its translation
    /// back to its place.
    public struct Segment: Sendable, Equatable {
        public var id: String
        public var text: String

        public init(id: String, text: String) {
            self.id = id
            self.text = text
        }
    }

    public let source: RecipeText
    public let segments: [Segment]
    /// Distinct section headings, in order of first use.
    private let headings: [String]
    /// For each ingredient, the amount kept as written, or nil when the
    /// whole line is translated.
    private let ingredientAmounts: [String?]

    public init(_ source: RecipeText) {
        self.source = source

        var headings: [String] = []
        for line in source.ingredients + source.steps {
            if let section = line.section, !Self.isBlank(section), !headings.contains(section) {
                headings.append(section)
            }
        }

        var segments: [Segment] = []
        Self.append("title", source.title, to: &segments)
        Self.append("summary", source.summary, to: &segments)
        for (index, heading) in headings.enumerated() {
            Self.append("section.\(index)", heading, to: &segments)
        }

        var amounts: [String?] = []
        for (index, line) in source.ingredients.enumerated() {
            let split = Self.splitAmount(line.text)
            amounts.append(split?.amount)
            Self.append("ingredient.\(index)", split?.rest ?? line.text, to: &segments)
        }
        for (index, line) in source.steps.enumerated() {
            Self.append("step.\(index)", line.text, to: &segments)
        }

        self.headings = headings
        self.ingredientAmounts = amounts
        self.segments = segments
    }

    /// The recipe with each piece replaced by its translation, keyed by
    /// segment id.
    public func apply(_ translations: [String: String]) -> RecipeText {
        func translated(_ id: String, _ fallback: String) -> String {
            guard let text = translations[id]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return fallback
            }
            return text
        }

        var translatedHeadings: [String: String] = [:]
        for (index, heading) in headings.enumerated() {
            translatedHeadings[heading] = translated("section.\(index)", heading)
        }
        func section(_ heading: String?) -> String? {
            heading.map { translatedHeadings[$0] ?? $0 }
        }

        let ingredients = source.ingredients.enumerated().map { (index, line) -> RecipeText.Line in
            let text: String
            if let amount = ingredientAmounts[index] {
                let rest = translated("ingredient.\(index)", "")
                text = rest.isEmpty ? line.text : amount + " " + rest
            } else {
                text = translated("ingredient.\(index)", line.text)
            }
            return RecipeText.Line(text, section: section(line.section))
        }
        let steps = source.steps.enumerated().map { (index, line) -> RecipeText.Line in
            RecipeText.Line(translated("step.\(index)", line.text), section: section(line.section))
        }

        return RecipeText(
            title: translated("title", source.title),
            summary: translated("summary", source.summary),
            ingredients: ingredients,
            steps: steps
        )
    }

    /// Splits "2 cuillères à soupe de farine" into ("2", "cuillères à soupe
    /// de farine") and "350g Mehl" into ("350g", "Mehl"). Nil when the line
    /// has no leading amount, or the amount runs into other text as in
    /// "1,5 kg" (a decimal comma the parser doesn't read), so the whole line
    /// is translated instead.
    static func splitAmount(_ line: String) -> (amount: String, rest: String)? {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = IngredientParser.parse(text)
        guard parsed.quantity != nil, text.hasSuffix(parsed.remainder) else { return nil }

        var amount = String(text.dropLast(parsed.remainder.count))
        var rest = Substring(parsed.remainder)
        // A unit written against the number, as in "350g", stays with it.
        let attachedUnit = rest.prefix { $0.isASCII && $0.isLetter }
        amount.append(contentsOf: attachedUnit)
        rest = rest.dropFirst(attachedUnit.count)

        guard let next = rest.first, next.isWhitespace else { return nil }
        let words = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return nil }
        return (amount.trimmingCharacters(in: .whitespaces), words)
    }

    private static func append(_ id: String, _ text: String, to segments: inout [Segment]) {
        guard !isBlank(text) else { return }
        segments.append(Segment(id: id, text: text))
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
