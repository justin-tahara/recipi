import Foundation

extension Units {
    /// Spoon and gram words from other languages, for recipes read in their
    /// own language (or when a translation leaves a unit as it was). They're
    /// matched before the English aliases because some are several words
    /// ("cuillère à soupe") or start like one ("c. à s." isn't a cup), and
    /// Japanese ones aren't followed by a space.
    private static let foreignAliasList: [(word: String, unit: String)] = [
        // German
        ("el", "tbsp"), ("esslöffel", "tbsp"), ("eßlöffel", "tbsp"),
        ("tl", "tsp"), ("teelöffel", "tsp"),
        ("gramm", "g"),
        // Italian
        ("cucchiaio", "tbsp"), ("cucchiai", "tbsp"),
        ("cucchiaino", "tsp"), ("cucchiaini", "tsp"),
        ("grammi", "g"),
        // French
        ("cuillère à soupe", "tbsp"), ("cuillères à soupe", "tbsp"),
        ("cuillere a soupe", "tbsp"), ("cuilleres a soupe", "tbsp"),
        ("c. à s.", "tbsp"), ("c.à.s.", "tbsp"), ("c. a s.", "tbsp"), ("c à s", "tbsp"), ("càs", "tbsp"),
        ("cuillère à café", "tsp"), ("cuillères à café", "tsp"),
        ("cuillere a cafe", "tsp"), ("cuilleres a cafe", "tsp"),
        ("c. à c.", "tsp"), ("c.à.c.", "tsp"), ("c. a c.", "tsp"), ("c à c", "tsp"), ("càc", "tsp"),
        ("gramme", "g"), ("grammes", "g"),
        // Spanish
        ("cucharada", "tbsp"), ("cucharadas", "tbsp"),
        ("cucharadita", "tsp"), ("cucharaditas", "tsp"),
        ("gramo", "g"), ("gramos", "g"),
        // Japanese
        ("大さじ", "tbsp"), ("小さじ", "tsp"), ("グラム", "g"),
    ]

    /// Longest first, so "cucchiaino" wins over "cucchiai".
    private static let foreignAliases = foreignAliasList.sorted { $0.word.count > $1.word.count }

    /// The foreign unit `text` starts with, normalised like the English
    /// ones, and how many characters it takes up. Case is ignored. A word
    /// has to end where the unit does ("el" isn't the start of "elotes"),
    /// except in Japanese, where the name often follows with no space.
    static func foreignMatch(atStartOf text: some StringProtocol) -> (unit: String, length: Int)? {
        for alias in foreignAliases {
            let length = alias.word.count
            let candidate = text.prefix(length)
            guard candidate.count == length, candidate.lowercased() == alias.word else { continue }
            if endsInWord(alias.word), let next = text.dropFirst(length).first, next.isLetter {
                continue
            }
            return (alias.unit, length)
        }
        return nil
    }

    /// True when the word ends in a letter of an alphabet that separates
    /// words with spaces (not Japanese kana or kanji).
    private static func endsInWord(_ word: String) -> Bool {
        guard let last = word.unicodeScalars.last else { return false }
        return last.properties.isAlphabetic && last.value < 0x3000
    }
}
