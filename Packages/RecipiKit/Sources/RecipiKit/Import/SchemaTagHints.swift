import Foundation

extension RecipeDraft {
    /// The parts of a page's schema.org `NutritionInformation` recipi uses,
    /// per serving.
    public struct Nutrition: Sendable, Equatable {
        /// Kilocalories per serving.
        public var calories: Double?
        /// Grams of protein per serving.
        public var proteinGrams: Double?

        public init(calories: Double? = nil, proteinGrams: Double? = nil) {
            self.calories = calories
            self.proteinGrams = proteinGrams
        }
    }
}

/// Reads the schema.org values that only feed automatic tags: `nutrition`
/// and `suitableForDiet`. Pages write numbers loosely ("320 kcal",
/// "1,200 calories", "28,5 g"), so this is forgiving and ignores values
/// that can't be right.
enum SchemaTagHints {
    static func nutrition(from value: Any?) -> RecipeDraft.Nutrition? {
        let node: [String: Any]?
        switch value {
        case let object as [String: Any]: node = object
        case let array as [Any]: node = array.lazy.compactMap { $0 as? [String: Any] }.first
        default: node = nil
        }
        guard let node else { return nil }

        var nutrition = RecipeDraft.Nutrition()
        if case let (value, unit)? = amount(in: node["calories"]) {
            // A few sites give energy in kilojoules.
            let kilocalories = unit.hasPrefix("kj") ? value / 4.184 : value
            if (20...5_000).contains(kilocalories) { nutrition.calories = kilocalories }
        }
        if case let (value, unit)? = amount(in: node["proteinContent"]) {
            let grams = unit.hasPrefix("mg") ? value / 1_000 : value
            if (0...300).contains(grams) { nutrition.proteinGrams = grams }
        }
        guard nutrition.calories != nil || nutrition.proteinGrams != nil else { return nil }
        return nutrition
    }

    /// `suitableForDiet` as bare names, e.g. "VeganDiet" for
    /// "https://schema.org/VeganDiet".
    static func diets(from value: Any?) -> [String] {
        let raw: [String]
        switch value {
        case let string as String: raw = [string]
        case let array as [Any]: raw = array.compactMap { ($0 as? String) ?? (($0 as? [String: Any])?["@id"] as? String) }
        case let object as [String: Any]: raw = [object["@id"] as? String].compactMap { $0 }
        default: raw = []
        }
        return raw.compactMap { entry in
            let name = entry.split(whereSeparator: { $0 == "/" || $0 == ":" || $0 == "#" }).last.map(String.init)
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    /// The first number in a value and the lowercased text after it:
    /// "1,200 kcal" gives (1200, "kcal"), 30 gives (30, "").
    static func amount(in value: Any?) -> (Double, String)? {
        switch value {
        case let number as NSNumber:
            return (number.doubleValue, "")
        case let array as [Any]:
            return array.lazy.compactMap { amount(in: $0) }.first
        case let object as [String: Any]:
            return amount(in: object["@value"] ?? object["value"])
        case let string as String:
            return amount(inText: string)
        default:
            return nil
        }
    }

    private static func amount(inText string: String) -> (Double, String)? {
        guard let start = string.firstIndex(where: { decimalDigit($0) != nil }) else { return nil }
        var number = ""
        var end = string.endIndex
        var index = start
        while index < string.endIndex {
            let character = string[index]
            if let digit = decimalDigit(character) {
                number.append(String(digit))
            } else if character == "." || character == "," {
                number.append(character)
            } else {
                end = index
                break
            }
            index = string.index(after: index)
        }
        // Trailing separators belong to the sentence, not the number.
        while number.last == "." || number.last == "," { number.removeLast() }
        guard let value = Double(standardized(number)) else { return nil }
        let unit = string[end...].trimmingCharacters(in: .whitespaces).lowercased()
        return (value, unit)
    }

    /// "1,200" and "1.200,5" as Double can read them. A comma followed by
    /// exactly three digits separates thousands; otherwise it's a decimal
    /// comma ("28,5"). With both, the last one is the decimal point.
    private static func standardized(_ number: String) -> String {
        let hasComma = number.contains(","), hasPoint = number.contains(".")
        if hasComma && hasPoint {
            let lastComma = number.lastIndex(of: ",")!, lastPoint = number.lastIndex(of: ".")!
            if lastComma > lastPoint {
                return number.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            }
            return number.replacingOccurrences(of: ",", with: "")
        }
        if hasComma {
            let groups = number.split(separator: ",", omittingEmptySubsequences: false)
            if groups.count > 1, groups.dropFirst().allSatisfy({ $0.count == 3 }) {
                return number.replacingOccurrences(of: ",", with: "")
            }
            return number.replacingOccurrences(of: ",", with: ".")
        }
        let groups = number.split(separator: ".", omittingEmptySubsequences: false)
        if groups.count > 2 {
            // "1.200.000": points as thousands separators.
            return number.replacingOccurrences(of: ".", with: "")
        }
        return number
    }

    private static func decimalDigit(_ character: Character) -> Int? {
        guard character.unicodeScalars.count == 1,
              character.unicodeScalars.first?.properties.numericType == .decimal else { return nil }
        return character.wholeNumberValue
    }
}
