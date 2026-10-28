import Foundation

/// Parses ISO 8601 durations as schema.org uses them for recipe times,
/// e.g. "PT1H30M" or "P0DT0H20M".
public enum ISO8601Duration {
    public static func seconds(from string: String) -> TimeInterval? {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard value.hasPrefix("P") else { return nil }

        var total: TimeInterval = 0
        var number = ""
        var inTimePart = false
        var sawComponent = false

        for character in value.dropFirst() {
            if character.isNumber || character == "." || character == "," {
                number.append(character == "," ? "." : character)
                continue
            }
            if character == "T" {
                inTimePart = true
                continue
            }
            guard let amount = Double(number) else { return nil }
            number = ""

            let unit: TimeInterval
            switch (character, inTimePart) {
            case ("Y", false): unit = 365 * 86_400
            case ("M", false): unit = 30 * 86_400
            case ("W", false): unit = 7 * 86_400
            case ("D", false): unit = 86_400
            case ("H", true): unit = 3_600
            case ("M", true): unit = 60
            case ("S", true): unit = 1
            default: return nil
            }
            total += amount * unit
            sawComponent = true
        }

        guard sawComponent, number.isEmpty else { return nil }
        return total
    }
}
