import Foundation

/// How amounts are shown: exactly as the recipe wrote them, or in US or
/// metric units. Conversion is like-for-like only (volume to volume, weight
/// to weight), so a cup of flour never turns into grams.
public enum MeasurementPreference: String, CaseIterable, Identifiable, Sendable, PreferenceValue {
    case asWritten
    case us
    case metric

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .asWritten: "As written"
        case .us: "US"
        case .metric: "Metric"
        }
    }

    /// US on devices set to US units, metric everywhere else.
    public static func deviceDefault(for locale: Locale = .current) -> MeasurementPreference {
        locale.measurementSystem == .us ? .us : .metric
    }

    fileprivate var system: MeasureUnit.System? {
        switch self {
        case .asWritten: nil
        case .us: .us
        case .metric: .metric
        }
    }
}

/// A unit we know how to convert. Count units ("2 cloves", "1 can") and
/// pinches stay as written.
enum MeasureUnit: Sendable, CaseIterable {
    case teaspoon, tablespoon, cup, fluidOunce, milliliter, liter
    case gram, kilogram, ounce, pound

    enum Dimension { case volume, mass }
    enum System { case us, metric }

    init?(normalizedName: String) {
        switch normalizedName {
        case "tsp": self = .teaspoon
        case "tbsp": self = .tablespoon
        case "cup": self = .cup
        case "ml": self = .milliliter
        case "l": self = .liter
        case "g": self = .gram
        case "kg": self = .kilogram
        case "oz": self = .ounce
        case "lb": self = .pound
        default: return nil
        }
    }

    var dimension: Dimension {
        switch self {
        case .teaspoon, .tablespoon, .cup, .fluidOunce, .milliliter, .liter: .volume
        case .gram, .kilogram, .ounce, .pound: .mass
        }
    }

    var system: System {
        switch self {
        case .teaspoon, .tablespoon, .cup, .fluidOunce, .ounce, .pound: .us
        case .milliliter, .liter, .gram, .kilogram: .metric
        }
    }

    /// Milliliters for volume units, grams for weight units.
    var baseAmount: Double {
        switch self {
        case .teaspoon: 4.92892
        case .tablespoon: 14.7868
        case .cup: 236.588
        case .fluidOunce: 29.5735
        case .milliliter: 1
        case .liter: 1000
        case .gram: 1
        case .kilogram: 1000
        case .ounce: 28.3495
        case .pound: 453.592
        }
    }

    func label(plural: Bool) -> String {
        switch self {
        case .teaspoon: "tsp"
        case .tablespoon: "tbsp"
        case .cup: plural ? "cups" : "cup"
        case .fluidOunce: "fl oz"
        case .milliliter: "ml"
        case .liter: "L"
        case .gram: "g"
        case .kilogram: "kg"
        case .ounce: "oz"
        case .pound: "lb"
        }
    }

    /// The unit a cook would use for `base` (ml or g) in `system`, e.g. 15 ml
    /// reads as 1 tbsp in US units and 1,200 g as 1.2 kg in metric.
    static func best(for base: Double, dimension: Dimension, system: System) -> MeasureUnit {
        switch (dimension, system) {
        case (.volume, .metric): base >= 1000 ? .liter : .milliliter
        case (.mass, .metric): base >= 1000 ? .kilogram : .gram
        case (.volume, .us):
            switch base / MeasureUnit.teaspoon.baseAmount {
            case ..<3: .teaspoon
            case ..<12: .tablespoon
            default: .cup
            }
        case (.mass, .us): base / MeasureUnit.ounce.baseAmount < 16 ? .ounce : .pound
        }
    }

    /// `base` (ml or g) written in this unit and rounded the way a cook would:
    /// "115" grams rather than "113.4", "⅓" cup rather than "0.35".
    func friendlyAmount(fromBase base: Double) -> (text: String, value: Double) {
        let value = base / baseAmount
        let rounded: Double
        switch self {
        case .milliliter:
            rounded = value < 10 ? max(1, value.rounded()) : (value < 100 ? Self.round(value, toNearest: 5) : Self.round(value, toNearest: 10))
            return (Self.metricString(rounded), rounded)
        case .gram:
            rounded = value < 25 ? max(1, value.rounded()) : Self.round(value, toNearest: 5)
            return (Self.metricString(rounded), rounded)
        case .liter, .kilogram:
            rounded = max(0.1, Self.round(value, toNearest: 0.1))
            return (Self.metricString(rounded), rounded)
        case .teaspoon:
            rounded = Self.kitchenRound(value, fractions: [0, 1.0 / 8, 1.0 / 4, 1.0 / 2, 3.0 / 4, 1])
        case .tablespoon:
            rounded = Self.kitchenRound(value, fractions: [0, 1.0 / 2, 1])
        case .cup, .pound:
            rounded = Self.kitchenRound(value, fractions: [0, 1.0 / 4, 1.0 / 3, 1.0 / 2, 2.0 / 3, 3.0 / 4, 1])
        case .ounce, .fluidOunce:
            rounded = Self.kitchenRound(value, fractions: [0, 1.0 / 4, 1.0 / 2, 3.0 / 4, 1])
        }
        return (QuantityFormatter.string(from: rounded), rounded)
    }

    private static func round(_ value: Double, toNearest step: Double) -> Double {
        (value / step).rounded() * step
    }

    /// Rounds to the nearest whole number plus one of `fractions`, never to 0.
    private static func kitchenRound(_ value: Double, fractions: [Double]) -> Double {
        let whole = value.rounded(.down)
        let remainder = value - whole
        let nearest = fractions.min { abs($0 - remainder) < abs($1 - remainder) } ?? 0
        let result = whole + nearest
        if result > 0 { return result }
        return fractions.first { $0 > 0 } ?? value
    }

    /// "115", "1.2", "5" (no trailing ".0").
    private static func metricString(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        var text = String(format: "%.1f", value)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return text
    }
}

enum UnitConverter {
    /// The convertible unit at the start of an ingredient's remainder and the
    /// text after it, e.g. " cups flour" → (.cup, " flour"). Handles "fl oz"
    /// (otherwise "oz" means weight) and a trailing period ("tbsp.").
    static func leadingUnit(in remainder: String) -> (unit: MeasureUnit, after: Substring)? {
        let start = remainder.drop { $0 == " " }
        let word = start.prefix { $0.isLetter }
        guard !word.isEmpty else { return nil }
        var after = start.dropFirst(word.count)

        if ["fl", "fluid"].contains(word.lowercased()) {
            if after.first == "." { after = after.dropFirst() }
            let next = after.drop { $0 == " " }
            let second = next.prefix { $0.isLetter }
            guard ["oz", "ounce", "ounces"].contains(second.lowercased()) else { return nil }
            after = next.dropFirst(second.count)
            if after.first == "." { after = after.dropFirst() }
            return (.fluidOunce, after)
        }

        guard let name = Units.normalized(firstWordOf: String(start)),
              let unit = MeasureUnit(normalizedName: name) else { return nil }
        if after.first == "." { after = after.dropFirst() }
        return (unit, after)
    }
}

extension ParsedIngredient {
    /// The line scaled by `factor` and shown in `preference`'s units, split
    /// into amount and the rest like `scaledParts(by:)`. Lines already in
    /// the chosen system, count units and lines without an amount are only
    /// scaled.
    public func displayParts(scaledBy factor: Double, in preference: MeasurementPreference) -> (amount: String, rest: String) {
        guard let converted = converted(scaledBy: factor, to: preference) else {
            return scaledParts(by: factor)
        }
        return converted
    }

    /// `displayParts(scaledBy:in:)` as one line, e.g. for the grocery list.
    public func display(scaledBy factor: Double, in preference: MeasurementPreference) -> String {
        let parts = displayParts(scaledBy: factor, in: preference)
        return parts.amount + parts.rest
    }

    private func converted(scaledBy factor: Double, to preference: MeasurementPreference) -> (amount: String, rest: String)? {
        guard let system = preference.system, let quantity,
              let leading = UnitConverter.leadingUnit(in: remainder),
              leading.unit.system != system else { return nil }
        let unit = leading.unit
        let factor = factor > 0 ? factor : 1
        let low = quantity * factor * unit.baseAmount
        let target = MeasureUnit.best(for: low, dimension: unit.dimension, system: system)
        let lowAmount = target.friendlyAmount(fromBase: low)
        var amount = lowAmount.text
        var largest = lowAmount.value
        if let upperQuantity {
            let highAmount = target.friendlyAmount(fromBase: upperQuantity * factor * unit.baseAmount)
            if highAmount.text != lowAmount.text {
                amount += "–" + highAmount.text
                largest = highAmount.value
            }
        }
        return (amount, " " + target.label(plural: largest > 1) + leading.after)
    }
}

/// Converts oven and cooking temperatures in step text, e.g. "350°F" →
/// "175°C" in metric. Only temperatures written with a degree sign, the
/// word "degrees" or a three-digit number right before F or C are touched.
public enum TemperatureConverter {
    public static func convert(_ text: String, to preference: MeasurementPreference) -> String {
        guard let target = preference.system else { return text }
        let from: Character = target == .metric ? "F" : "C"
        let patterns = [
            // 350°F, 350 °F, 350 degrees F, 180 degrees Celsius, 350º F
            #"\b(\d{2,3})(?:\s*[°º˚]\s*|\s*degrees?\s+|\s*deg\.?\s+)([FC])(?:ahrenheit|elsius)?\b"#,
            // 350F, 180 C (three digits only, so "2 C" stays cups)
            #"\b(\d{3})\s?([FC])\b"#,
        ]
        var result = text
        for (index, pattern) in patterns.enumerated() {
            let options: NSRegularExpression.Options = index == 0 ? [.caseInsensitive] : []
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { continue }
            let source = result as NSString
            var output = ""
            var cursor = 0
            for match in regex.matches(in: result, range: NSRange(location: 0, length: source.length)) {
                let scale = source.substring(with: match.range(at: 2)).uppercased()
                guard scale.first == from, let value = Double(source.substring(with: match.range(at: 1))) else { continue }
                output += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                output += from == "F" ? "\(celsius(fromFahrenheit: value))°C" : "\(fahrenheit(fromCelsius: value))°F"
                cursor = match.range.location + match.range.length
            }
            output += source.substring(from: cursor)
            result = output
        }
        return result
    }

    /// Oven settings land on multiples of 5 °C.
    static func celsius(fromFahrenheit value: Double) -> Int {
        let celsius = (value - 32) * 5 / 9
        return celsius >= 100 ? Int((celsius / 5).rounded() * 5) : Int(celsius.rounded())
    }

    /// Oven dials go in 25 °F steps; lower temperatures stay exact.
    static func fahrenheit(fromCelsius value: Double) -> Int {
        let fahrenheit = value * 9 / 5 + 32
        return fahrenheit >= 250 ? Int((fahrenheit / 25).rounded() * 25) : Int(fahrenheit.rounded())
    }
}
