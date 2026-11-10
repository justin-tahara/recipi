import Foundation

public enum IngredientParser {
    public static func parse(_ line: String) -> ParsedIngredient {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        var scanner = AmountScanner(text)

        guard let quantity = scanner.scanAmount() else {
            if let amountAfterItem = AmountAfterItem.parse(text, original: line) {
                return amountAfterItem
            }
            return ParsedIngredient(original: line, quantity: nil, upperQuantity: nil, remainder: text, unit: nil)
        }

        var upperQuantity: Double?
        let afterFirstAmount = scanner.position
        scanner.skipSpaces()
        if scanner.scanRangeSeparator() {
            scanner.skipSpaces()
            upperQuantity = scanner.scanAmount()
        }
        if upperQuantity == nil {
            scanner.position = afterFirstAmount
        }

        let remainder = scanner.remainder
        return ParsedIngredient(
            original: line,
            quantity: quantity,
            upperQuantity: upperQuantity,
            remainder: remainder,
            unit: Units.normalized(firstWordOf: remainder)
        )
    }
}

/// Reads amounts like "2", "1.5", "1,5", "1,000", "1/2", "1 1/2", "½", "1½"
/// and "1 ½".
struct AmountScanner {
    private let characters: [Character]
    var position = 0

    init(_ text: String) {
        characters = Array(text)
    }

    init(characters: [Character]) {
        self.characters = characters
    }

    var remainder: String {
        String(characters[min(position, characters.count)...])
    }

    mutating func skipSpaces() {
        while position < characters.count, characters[position] == " " {
            position += 1
        }
    }

    mutating func scanRangeSeparator() -> Bool {
        guard position < characters.count else { return false }
        let dashes: [Character] = ["-", "–", "—"]
        if dashes.contains(characters[position]) {
            position += 1
            return true
        }
        if characters[position...].starts(with: Array("to ")) || characters[position...].starts(with: Array("or ")) {
            position += 2
            return true
        }
        return false
    }

    mutating func scanAmount() -> Double? {
        let start = position
        if let vulgar = scanVulgarFraction() {
            return vulgar
        }
        guard let whole = scanNumber() else {
            position = start
            return nil
        }

        // "1/2"
        let afterWhole = position
        if scanFractionSlash(), let denominator = scanInteger(), denominator > 0 {
            return whole / Double(denominator)
        }
        position = afterWhole

        // "1½"
        if let vulgar = scanVulgarFraction() {
            return whole + vulgar
        }

        // "1 1/2" or "1 ½"
        if position < characters.count, characters[position] == " " {
            position += 1
            if let vulgar = scanVulgarFraction() {
                return whole + vulgar
            }
            if let numerator = scanInteger(), scanFractionSlash(), let denominator = scanInteger(), denominator > 0 {
                return whole + Double(numerator) / Double(denominator)
            }
            position = afterWhole
        }
        return whole
    }

    /// An amount as Japanese recipes write it: anything `scanAmount()`
    /// reads, or a whole number and a fraction joined by "と" ("1と1/2" is
    /// one and a half).
    mutating func scanJapaneseAmount() -> Double? {
        guard let whole = scanAmount() else { return nil }
        let afterWhole = position
        if position < characters.count, characters[position] == "と" {
            position += 1
            if let fraction = scanAmount(), fraction < 1 {
                return whole + fraction
            }
        }
        position = afterWhole
        return whole
    }

    /// The wave dash or dash in a Japanese range like "1〜2片".
    mutating func scanJapaneseRangeSeparator() -> Bool {
        let separators: [Character] = ["〜", "～", "~", "-", "–", "—"]
        guard position < characters.count, separators.contains(characters[position]) else { return false }
        position += 1
        return true
    }

    /// A whole or decimal number. Besides "1.5" it reads a comma as a
    /// thousands separator or, as recipes from much of Europe write it, a
    /// decimal comma:
    ///
    /// - A comma followed by exactly three digits separates thousands, as
    ///   in "1,000 g" or "12,500" (one to three digits before the first
    ///   comma, three in every group after it).
    /// - A comma followed by one or two digits is a decimal comma, as in
    ///   "1,5 kg" or "0,25 l", unless another comma or a point follows
    ///   ("1,5,6" stays 1).
    /// - Anything else after a comma ends the number, so "1, 2 or 3" and
    ///   "1,0000" read as 1. "1,2 or 3" reads as 1.2: without the space it
    ///   looks just like a decimal comma.
    private mutating func scanNumber() -> Double? {
        let start = position
        let wholeDigits = digitCount(from: position)
        guard wholeDigits > 0 else { return nil }
        position += wholeDigits
        var number = String(characters[start..<position])

        if isComma(at: position), wholeDigits <= 3, digitCount(from: position + 1) == 3 {
            while isComma(at: position), digitCount(from: position + 1) == 3 {
                number += String(characters[(position + 1)..<(position + 4)])
                position += 4
            }
        } else if isComma(at: position), (1...2).contains(digitCount(from: position + 1)) {
            let fractionStart = position + 1
            let fractionEnd = fractionStart + digitCount(from: fractionStart)
            let followedBySeparator = fractionEnd < characters.count && (characters[fractionEnd] == "," || characters[fractionEnd] == ".")
            if !followedBySeparator {
                position = fractionEnd
                return Double(number + "." + String(characters[fractionStart..<fractionEnd]))
            }
        }

        if position + 1 < characters.count, characters[position] == ".",
           characters[position + 1].isASCII, characters[position + 1].isNumber {
            let pointAt = position
            position += 1
            position += digitCount(from: position)
            number += String(characters[pointAt..<position])
        }
        return Double(number)
    }

    /// How many ASCII digits run from `index`.
    private func digitCount(from index: Int) -> Int {
        var end = index
        while end < characters.count, characters[end].isASCII, characters[end].isNumber {
            end += 1
        }
        return end - index
    }

    private func isComma(at index: Int) -> Bool {
        index < characters.count && characters[index] == ","
    }

    private mutating func scanInteger() -> Int? {
        let start = position
        while position < characters.count, characters[position].isASCII, characters[position].isNumber {
            position += 1
        }
        return position > start ? Int(String(characters[start..<position])) : nil
    }

    private mutating func scanFractionSlash() -> Bool {
        guard position < characters.count, characters[position] == "/" || characters[position] == "⁄" else {
            return false
        }
        position += 1
        return true
    }

    private mutating func scanVulgarFraction() -> Double? {
        guard position < characters.count, let value = Self.vulgarFractions[characters[position]] else {
            return nil
        }
        position += 1
        return value
    }

    static let vulgarFractions: [Character: Double] = [
        "½": 1.0 / 2, "⅓": 1.0 / 3, "⅔": 2.0 / 3, "¼": 1.0 / 4, "¾": 3.0 / 4,
        "⅕": 1.0 / 5, "⅖": 2.0 / 5, "⅗": 3.0 / 5, "⅘": 4.0 / 5, "⅙": 1.0 / 6,
        "⅚": 5.0 / 6, "⅛": 1.0 / 8, "⅜": 3.0 / 8, "⅝": 5.0 / 8, "⅞": 7.0 / 8,
    ]
}

enum Units {
    private static let aliases: [String: String] = [
        "cup": "cup", "cups": "cup", "c": "cup",
        "tablespoon": "tbsp", "tablespoons": "tbsp", "tbsp": "tbsp", "tbs": "tbsp", "tbl": "tbsp", "T": "tbsp",
        "teaspoon": "tsp", "teaspoons": "tsp", "tsp": "tsp", "t": "tsp",
        "gram": "g", "grams": "g", "g": "g",
        "kilogram": "kg", "kilograms": "kg", "kg": "kg",
        "milliliter": "ml", "milliliters": "ml", "millilitre": "ml", "millilitres": "ml", "ml": "ml",
        "liter": "l", "liters": "l", "litre": "l", "litres": "l", "l": "l",
        "ounce": "oz", "ounces": "oz", "oz": "oz",
        "pound": "lb", "pounds": "lb", "lb": "lb", "lbs": "lb",
        "pinch": "pinch", "pinches": "pinch",
        "clove": "clove", "cloves": "clove",
        "can": "can", "cans": "can",
        "stick": "stick", "sticks": "stick",
    ]

    static func normalized(firstWordOf remainder: String) -> String? {
        let trimmed = remainder.trimmingCharacters(in: .whitespaces)
        if let foreign = foreignMatch(atStartOf: trimmed) { return foreign.unit }
        let word = trimmed.prefix { $0.isLetter }
        guard !word.isEmpty else { return nil }
        let key = String(word)
        // "T" and "t" are the classic tablespoon/teaspoon shorthands, so
        // only those two are case-sensitive.
        if key == "T" || key == "t" { return aliases[key] }
        return aliases[key.lowercased()]
    }
}
