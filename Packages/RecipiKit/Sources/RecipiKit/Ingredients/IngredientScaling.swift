import Foundation

/// Works out how much to scale a whole recipe from one ingredient, as in
/// "the recipe wants 1 lb chicken and I have 2 lb".
public enum IngredientScaling {
    /// Units someone can say they have of this ingredient: its own unit
    /// first, then the others of the same kind (weight or volume). Empty when
    /// the line has no unit we can convert, like "3 eggs" or "2 cloves".
    public static func unitChoices(for ingredient: ParsedIngredient) -> [String] {
        guard let own = UnitConverter.leadingUnit(in: ingredient.remainder)?.unit else { return [] }
        let sameKind = MeasureUnit.allCases.filter { $0.dimension == own.dimension && $0 != own }
        return ([own] + sameKind).map { $0.label(plural: false) }
    }

    /// The factor that turns the recipe's amount of `ingredient` into
    /// `amount` of `unit` (one of `unitChoices(for:)`, or nil to use the
    /// line's own unit). Nil when the line has no amount, the amount isn't
    /// positive, or the units measure different things.
    public static func factor(for ingredient: ParsedIngredient, have amount: Double, unit: String?) -> Double? {
        guard let needed = ingredient.quantity, needed > 0, amount > 0, amount.isFinite else { return nil }
        guard let unit, let own = UnitConverter.leadingUnit(in: ingredient.remainder)?.unit,
              let chosen = MeasureUnit.allCases.first(where: { $0.label(plural: false) == unit }),
              chosen != own else {
            return amount / needed
        }
        guard chosen.dimension == own.dimension else { return nil }
        return (amount * chosen.baseAmount) / (needed * own.baseAmount)
    }

    /// What the line is about, without its amount, convertible unit or
    /// trailing notes: "1 lb chicken thighs, skin on" → "chicken thighs",
    /// "2 cloves garlic" → "cloves garlic".
    public static func itemName(of ingredient: ParsedIngredient) -> String {
        let rest = UnitConverter.leadingUnit(in: ingredient.remainder).map { String($0.after) } ?? ingredient.remainder
        let name = rest.split(separator: ",", maxSplits: 1).first.map(String.init) ?? rest
        return name.trimmingCharacters(in: .whitespaces)
    }

    /// A factor as people say it: "×2", "×½", "×1.5".
    public static func multiplierLabel(_ factor: Double) -> String {
        "×" + QuantityFormatter.string(from: factor)
    }
}
