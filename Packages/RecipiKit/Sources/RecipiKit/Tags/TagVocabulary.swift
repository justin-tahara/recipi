import Foundation

/// One tag of the built-in vocabulary: its name as recipi shows it, its
/// kind, the other ways recipe sites write it (in a few languages), and the
/// terms it also covers when filtering ("Asian" covers "Japanese").
public struct VocabularyTerm: Sendable, Hashable, Identifiable {
    public let name: String
    public let kind: TagKind
    public let synonyms: [String]
    /// Names of other terms this one matches when it's a filter.
    public let includes: [String]

    public var id: String { name }

    /// A cuisine that stands for several others, like "Asian".
    public var isGroup: Bool { kind == .cuisine && !includes.isEmpty }

    init(_ name: String, _ kind: TagKind, _ synonyms: [String], includes: [String] = []) {
        self.name = name
        self.kind = kind
        self.synonyms = synonyms
        self.includes = includes
    }
}

/// The tags recipi knows about. Imported categories, cuisines and keywords
/// are matched against it so "italiano", "Italian recipes" and "Italian"
/// all become one "Italian" tag. Everything here runs on device.
public enum TagVocabulary {
    /// Every term, cuisines first, in the order chips are listed.
    public static var terms: [VocabularyTerm] { allTerms }

    public static func terms(of kind: TagKind) -> [VocabularyTerm] {
        allTerms.filter { $0.kind == kind }
    }

    /// The term with this exact name, ignoring case and accents.
    public static func term(named name: String) -> VocabularyTerm? {
        byName[normalized(name)]
    }

    /// The single term a value means, like "japonais" or "Italian food".
    /// Nil when it means none, or several ("vegetarian dinner").
    public static func term(matching value: String) -> VocabularyTerm? {
        guard let found = terms(in: value), found.count == 1 else { return nil }
        return found[0]
    }

    /// The terms a value is made of, or nil unless every word of it is part
    /// of a term or a filler word like "easy" or "recipes". "Quick vegetarian
    /// dinner" gives three terms; "French toast" and "Greek yogurt" give nil,
    /// because toast and yogurt aren't terms.
    public static func terms(in value: String) -> [VocabularyTerm]? {
        let key = normalized(value)
        guard !key.isEmpty else { return nil }
        if let term = index[key] { return [term] }

        let words = key.split(separator: " ").map(String.init)
        var found: [VocabularyTerm] = []
        var position = 0
        scanning: while position < words.count {
            let longest = min(maxPhraseWords, words.count - position)
            for length in stride(from: longest, through: 1, by: -1) {
                let phrase = words[position..<(position + length)].joined(separator: " ")
                if let term = index[phrase] {
                    if !found.contains(term) { found.append(term) }
                    position += length
                    continue scanning
                }
            }
            guard fillerWords.contains(words[position]) else { return nil }
            position += 1
        }
        return found.isEmpty ? nil : found
    }

    /// Names of the terms a term covers when it's a filter, itself included.
    /// "Asian" covers Japanese, Korean, Chinese and so on; "Vegetarian"
    /// covers "Vegan".
    public static func coverage(of term: VocabularyTerm) -> Set<String> {
        coverageByName[term.name] ?? [term.name]
    }

    /// True when a filter chip named `chipName` should show a recipe tagged
    /// `tagName`: the same name, the same term written another way, or a
    /// term the chip's term covers.
    public static func chip(named chipName: String, matchesTagNamed tagName: String) -> Bool {
        let chipKey = normalized(chipName)
        if chipKey == normalized(tagName) { return true }
        guard let chipTerm = term(matching: chipName), let tagTerm = term(matching: tagName) else { return false }
        return coverage(of: chipTerm).contains(tagTerm.name)
    }

    /// Lowercased, without accents or width differences, punctuation turned
    /// into spaces and runs of spaces collapsed. "Gluten-Free!" and
    /// "gluten free" read the same.
    public static func normalized(_ value: String) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        var result = ""
        var pendingSpace = false
        for character in folded {
            if character == "'" || character == "’" || character == "`" {
                continue
            }
            if character.isLetter || character.isNumber {
                if pendingSpace && !result.isEmpty { result.append(" ") }
                pendingSpace = false
                result.append(character)
            } else {
                pendingSpace = true
            }
        }
        return result
    }

    // MARK: - Lookup tables

    static let maxPhraseWords = 4

    /// Words that don't change what a value means: "easy dinner" is dinner,
    /// "Italian recipes" is Italian.
    static let fillerWords: Set<String> = [
        "recipe", "recipes", "food", "foods", "cuisine", "cooking", "dish", "dishes", "style", "inspired",
        "meal", "meals", "idea", "ideas", "easy", "simple", "best", "classic", "homemade", "authentic",
        "traditional", "and", "the", "or", "a",
    ]

    /// Normalized names and synonyms to terms. If two terms ever claim the
    /// same word, the first listed wins (a test checks there are none).
    static let index: [String: VocabularyTerm] = {
        var index: [String: VocabularyTerm] = [:]
        for term in allTerms {
            for key in [term.name] + term.synonyms {
                let normalizedKey = normalized(key)
                if !normalizedKey.isEmpty, index[normalizedKey] == nil {
                    index[normalizedKey] = term
                }
            }
        }
        return index
    }()

    static let byName: [String: VocabularyTerm] = {
        var byName: [String: VocabularyTerm] = [:]
        for term in allTerms { byName[normalized(term.name)] = term }
        return byName
    }()

    static let coverageByName: [String: Set<String>] = {
        var coverage: [String: Set<String>] = [:]
        for term in allTerms {
            var covered: Set<String> = [term.name]
            var pending = term.includes
            while let next = pending.popLast() {
                guard covered.insert(next).inserted else { continue }
                pending += byName[normalized(next)]?.includes ?? []
            }
            coverage[term.name] = covered
        }
        return coverage
    }()
}
