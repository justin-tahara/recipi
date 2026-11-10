import Foundation

/// Japanese recipes write the amount after the item: "砂糖 大さじ2",
/// "醤油 大さじ1と1/2", "卵 2個", "水 200ml". This reads those lines so they
/// scale like "2 tbsp sugar" does, and keeps them in their own order:
/// "砂糖 大さじ2" doubled is "砂糖 大さじ4".
///
/// It's kept narrow so English lines are never read this way. The line has
/// to end with the amount and a unit we know, written either before the
/// amount (大さじ, 小さじ, カップ) or after it (g, kg, ml, cc, L, グラム, カップ,
/// and the counters 個, 本, 枚, 片), and the item has to be written in
/// Japanese. Anything else, like "ご飯 2杯分" or "砂糖 大さじ2（お好みで）",
/// is left without an amount, as before.
enum AmountAfterItem {
    /// Units written before the amount, as in "大さじ2" or "カップ1".
    private static let unitsBefore: [(word: String, unit: String)] = [
        ("大さじ", "tbsp"), ("小さじ", "tsp"), ("カップ", japaneseCup),
    ]

    /// Units written after the amount, as in "200ml" or "2個". The whole
    /// rest of the line has to be one of these, ignoring case and spaces.
    private static let unitsAfter: [String: String] = [
        "g": "g", "グラム": "g", "kg": "kg",
        "ml": "ml", "cc": "ml", "l": "l",
        "カップ": japaneseCup,
        "個": "個", "本": "本", "枚": "枚", "片": "片",
    ]

    /// A Japanese cup is 200 ml, not a US cup (about 237 ml), so it's its own
    /// unit: it scales but isn't converted.
    static let japaneseCup = "カップ"

    /// The line read with its amount after the item, or nil when it doesn't
    /// end that way. `text` is the trimmed line and `original` the line as
    /// given, which scaling by 1 returns.
    static func parse(_ text: String, original: String) -> ParsedIngredient? {
        let characters = Array(text)
        // Full-width digits, slashes and letters ("２", "／", "ｍｌ") are read
        // as ASCII. Each maps to one character, so positions in `normalized`
        // are positions in the line as written.
        let normalized = characters.map(halfWidth)

        for start in characters.indices.dropFirst() where startsAmount(at: start, in: normalized) {
            var scanner = AmountScanner(characters: normalized)
            scanner.position = start
            guard let quantity = scanner.scanJapaneseAmount() else { continue }

            var upperQuantity: Double?
            let afterFirstAmount = scanner.position
            scanner.skipSpaces()
            if scanner.scanJapaneseRangeSeparator() {
                scanner.skipSpaces()
                upperQuantity = scanner.scanJapaneseAmount()
            }
            if upperQuantity == nil {
                scanner.position = afterFirstAmount
            }
            let end = scanner.position

            let lead = String(characters[..<start])
            let after = String(normalized[end...]).trimmingCharacters(in: .whitespaces).lowercased()
            let unit: String
            let item: Substring
            if let before = unitBefore(endOf: lead) {
                guard after.isEmpty else { continue }
                unit = before.unit
                item = before.item
            } else if let afterUnit = unitsAfter[after] {
                unit = afterUnit
                item = Substring(lead)
            } else {
                continue
            }
            guard isJapanese(item) else { continue }

            return ParsedIngredient(
                original: original,
                quantity: quantity,
                upperQuantity: upperQuantity,
                remainder: String(characters[end...]),
                unit: unit,
                lead: lead
            )
        }
        return nil
    }

    /// The unit `lead` ends with, if it's one written before the amount,
    /// and the item before it: "砂糖 大さじ" → ("tbsp", "砂糖 ").
    static func unitBefore(endOf lead: String) -> (unit: String, item: Substring)? {
        var trimmed = Substring(lead)
        while let last = trimmed.last, last.isWhitespace {
            trimmed = trimmed.dropLast()
        }
        for candidate in unitsBefore where trimmed.hasSuffix(candidate.word) {
            return (candidate.unit, trimmed.dropLast(candidate.word.count))
        }
        return nil
    }

    /// An amount can start at `index`: a digit or fraction that doesn't
    /// continue a number before it.
    private static func startsAmount(at index: Int, in characters: [Character]) -> Bool {
        let character = characters[index]
        guard (character.isASCII && character.isNumber) || AmountScanner.vulgarFractions[character] != nil else {
            return false
        }
        let previous = characters[index - 1]
        return !(previous.isASCII && previous.isNumber) && previous != "." && previous != "," && previous != "/"
    }

    /// True when `text` has kana or kanji in it.
    private static func isJapanese(_ text: Substring) -> Bool {
        text.unicodeScalars.contains { scalar in
            let value = scalar.value
            // Hiragana and katakana, CJK ideographs, and 々.
            return (0x3040...0x30FF).contains(value) || (0x3400...0x4DBF).contains(value)
                || (0x4E00...0x9FFF).contains(value) || value == 0x3005
        }
    }

    /// Full-width ASCII ("２", "ｇ", "／", "～") as plain ASCII, and the wave
    /// dash as "~". Everything else as it is.
    private static func halfWidth(_ character: Character) -> Character {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else {
            return character
        }
        if scalar.value == 0x301C { return "~" }
        guard (0xFF01...0xFF5E).contains(scalar.value),
              let ascii = Unicode.Scalar(scalar.value - 0xFEE0) else { return character }
        return Character(ascii)
    }
}
