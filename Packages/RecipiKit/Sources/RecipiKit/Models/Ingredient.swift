import Foundation
import SwiftData

@Model
public final class Ingredient {
    /// The line as written, e.g. "1 1/2 cups flour, sifted". Quantities are
    /// parsed from this on display so scaling never drifts from what the
    /// person typed or imported.
    public var text: String = ""
    public var order: Int = 0
    /// Optional group heading, e.g. "For the sauce".
    public var section: String?
    public var recipe: Recipe?

    public init(text: String, order: Int, section: String? = nil) {
        self.text = text
        self.order = order
        self.section = section
    }
}

extension Ingredient {
    public var parsed: ParsedIngredient { IngredientParser.parse(text) }
}
