import Foundation

/// An ingredient line split into the three parts the editor shows side by
/// side: amount, unit and name. "1 1/2 cups flour, sifted" becomes
/// ("1 1/2", "cups", "flour, sifted"). The amount and unit are kept as
/// written, so splitting a line and joining it again doesn't rewrite it
/// beyond tidying the spaces between parts.
public struct IngredientParts: Sendable, Equatable {
    public var amount: String
    public var unit: String
    public var name: String

    public init(amount: String = "", unit: String = "", name: String = "") {
        self.amount = amount
        self.unit = unit
        self.name = name
    }

    /// Splits a line with `IngredientParser`. A unit is only split off when
    /// the parser recognises it, so "1 (14 oz) can tomatoes" keeps
    /// "(14 oz) can tomatoes" as its name.
    public init(parsing line: String) {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = IngredientParser.parse(text)
        guard parsed.quantity != nil, text.hasSuffix(parsed.remainder) else {
            self.init(name: text)
            return
        }

        let amount = String(text.dropLast(parsed.remainder.count)).trimmingCharacters(in: .whitespaces)
        var rest = Substring(parsed.remainder.trimmingCharacters(in: .whitespaces))
        var unit = ""
        if parsed.unit != nil {
            // The parser read the unit from the leading letters; take the
            // same letters as written, plus a trailing "." as in "tbsp.".
            var end = rest.firstIndex { !$0.isLetter } ?? rest.endIndex
            if end < rest.endIndex, rest[end] == "." {
                end = rest.index(after: end)
            }
            unit = String(rest[..<end])
            rest = rest[end...]
        }
        self.init(amount: amount, unit: unit, name: rest.trimmingCharacters(in: .whitespaces))
    }

    /// The parts joined back into one line.
    public var line: String {
        [amount, unit, name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
