import Foundation

public enum IngredientParser {
    public static func parse(_ line: String) -> ParsedIngredient {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        var scanner = AmountScanner(text)

        guard let quantity = scanner.scanAmount() else {
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

/// Reads amounts like "2", "1.5", "1/2", "1 1/2", "½", "1½" and "1 ½".
struct AmountScanner {
    private let characters: [Character]
    var position = 0

    init(_ text: String) {
        characters = Array(text)
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

    private mutating func scanNumber() -> Double? {
        let start = position
        while position < characters.count, characters[position].isASCII, characters[position].isNumber {
            position += 1
        }
        guard position > start else { return nil }
        if position + 1 < characters.count, characters[position] == ".",
           characters[position + 1].isASCII, characters[position + 1].isNumber {
            position += 1
            while position < characters.count, characters[position].isASCII, characters[position].isNumber {
                position += 1
            }
        }
        return Double(String(characters[start..<position]))
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

    private static let vulgarFractions: [Character: Double] = [
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
        let word = remainder
            .trimmingCharacters(in: .whitespaces)
            .prefix { $0.isLetter }
        guard !word.isEmpty else { return nil }
        let key = String(word)
        // "T" and "t" are the classic tablespoon/teaspoon shorthands, so
        // only those two are case-sensitive.
        if key == "T" || key == "t" { return aliases[key] }
        return aliases[key.lowercased()]
    }
}
