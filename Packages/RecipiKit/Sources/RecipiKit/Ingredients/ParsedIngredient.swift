import Foundation

/// An ingredient line split into its leading amount and everything after
/// it. Scaling only touches the amount and leaves the rest exactly as
/// written, so "1 (14 oz) can tomatoes" scales the can count, not the 14 oz.
public struct ParsedIngredient: Sendable, Equatable {
    public var original: String
    public var quantity: Double?
    /// Upper end of a range like "2-3 cloves garlic".
    public var upperQuantity: Double?
    /// The text after the amount, including any unit, e.g. " cups flour".
    public var remainder: String
    /// The unit, normalised, when it's one we recognise.
    public var unit: String?

    public init(original: String, quantity: Double?, upperQuantity: Double?, remainder: String, unit: String?) {
        self.original = original
        self.quantity = quantity
        self.upperQuantity = upperQuantity
        self.remainder = remainder
        self.unit = unit
    }

    /// The line with its amount multiplied by `factor`.
    public func scaled(by factor: Double) -> String {
        guard let quantity, factor != 1, factor > 0 else { return original }
        var amount = QuantityFormatter.string(from: quantity * factor)
        if let upperQuantity {
            amount += "–" + QuantityFormatter.string(from: upperQuantity * factor)
        }
        return amount + remainder
    }
}
