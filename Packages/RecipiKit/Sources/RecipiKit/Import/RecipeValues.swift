import Foundation

/// Reads the loosely written values recipe pages put in yields and times.
/// Shared by both parsers.
enum RecipeValues {
    /// The serving count in a yield like "4", "Serves 4-6", "4 Portionen" or
    /// "2人分". Only decimal digits count, ASCII or full-width.
    static func servings(in yield: String) -> Int? {
        var digits = ""
        for character in yield {
            if let digit = decimalDigit(character) {
                digits.append(String(digit))
            } else if !digits.isEmpty {
                break
            }
        }
        guard digits.count <= 6, let value = Int(digits), value > 0 else { return nil }
        return value
    }

    private static func decimalDigit(_ character: Character) -> Int? {
        guard character.unicodeScalars.count == 1,
              character.unicodeScalars.first?.properties.numericType == .decimal else { return nil }
        return character.wholeNumberValue
    }

    /// The yield text to keep, given every value a page listed. Pages often
    /// list a bare number and then a fuller version ("4", "4 servings"); the
    /// fuller one reads better as long as it's about the same count.
    static func yieldText(from yields: [String]) -> String? {
        guard let first = yields.first else { return nil }
        let count = servings(in: first)
        return yields.first { yield in
            yield.contains { $0.isLetter } && servings(in: yield) == count
        } ?? first
    }

    /// A recipe time in seconds, from an ISO 8601 duration ("PT1H30M") or the
    /// way people write it ("1 hour 30 mins", "45 Min.", "1時間30分"). A zero
    /// time is treated as unknown, since that's what pages that emit "PT0M"
    /// mean by it.
    static func duration(from text: String) -> TimeInterval? {
        guard let seconds = ISO8601Duration.seconds(from: text) ?? writtenDuration(text), seconds > 0 else {
            return nil
        }
        return seconds
    }

    private static let hourWords: Set<String> = [
        "h", "hr", "hrs", "hour", "hours", "std", "stunde", "stunden", "heure", "heures", "ora", "ore", "時間",
    ]
    private static let minuteWords: Set<String> = [
        "m", "mn", "min", "mins", "minute", "minutes", "minuten", "minuti", "minuto", "分",
    ]

    private static func writtenDuration(_ text: String) -> TimeInterval? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+(?:[.,]\d+)?)\s*(時間|分|[a-zà-ÿ]+)"#, options: [.caseInsensitive]) else {
            return nil
        }
        var total: TimeInterval = 0
        var sawUnit = false
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let numberRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let amount = Double(text[numberRange].replacingOccurrences(of: ",", with: ".")) else { continue }
            let unit = text[unitRange].lowercased()
            if hourWords.contains(unit) {
                total += amount * 3_600
            } else if minuteWords.contains(unit) {
                total += amount * 60
            } else {
                continue
            }
            sawUnit = true
        }
        return sawUnit ? total : nil
    }
}
