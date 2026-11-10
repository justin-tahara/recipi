import Foundation

/// An ingredient line split into its amount and the text around it.
/// Scaling only touches the amount and leaves the rest exactly as written,
/// so "1 (14 oz) can tomatoes" scales the can count, not the 14 oz.
///
/// Most lines start with their amount. Japanese lines put it after the item
/// ("砂糖 大さじ2"), and the text before the amount is then `lead`.
public struct ParsedIngredient: Sendable, Equatable {
    public var original: String
    public var quantity: Double?
    /// Upper end of a range like "2-3 cloves garlic".
    public var upperQuantity: Double?
    /// The text after the amount, including any unit, e.g. " cups flour".
    public var remainder: String
    /// The unit, normalised, when it's one we recognise.
    public var unit: String?
    /// The text before the amount, for lines that write the item first:
    /// "砂糖 大さじ" in "砂糖 大さじ2", "卵 " in "卵 2個". Empty for lines that
    /// start with their amount.
    public var lead: String

    public init(original: String, quantity: Double?, upperQuantity: Double?, remainder: String, unit: String?, lead: String = "") {
        self.original = original
        self.quantity = quantity
        self.upperQuantity = upperQuantity
        self.remainder = remainder
        self.unit = unit
        self.lead = lead
    }

    /// The line with its amount multiplied by `factor`.
    public func scaled(by factor: Double) -> String {
        guard let quantity, factor != 1, factor > 0 else { return original }
        var amount = QuantityFormatter.string(from: quantity * factor)
        if let upperQuantity {
            amount += "–" + QuantityFormatter.string(from: upperQuantity * factor)
        }
        return lead + amount + remainder
    }

    /// The scaled line split around its amount, so a view can set the
    /// amount apart, e.g. ("", "1½", " cups flour") or ("砂糖 大さじ", "4", "").
    /// Lines without an amount come back whole as `rest`.
    public func scaledParts(by factor: Double) -> (lead: String, amount: String, rest: String) {
        let line = scaled(by: factor)
        guard quantity != nil, !(lead.isEmpty && remainder.isEmpty),
              line.count > lead.count + remainder.count,
              line.hasPrefix(lead), line.hasSuffix(remainder) else {
            return ("", "", line)
        }
        let amount = line.dropFirst(lead.count).dropLast(remainder.count)
        return (lead, String(amount), remainder)
    }
}
