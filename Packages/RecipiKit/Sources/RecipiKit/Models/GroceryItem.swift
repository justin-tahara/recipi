import Foundation
import SwiftData

@Model
public final class GroceryItem {
    public var text: String = ""
    public var isChecked: Bool = false
    /// Title of the recipe this came from, kept as text so deleting the
    /// recipe doesn't empty the list.
    public var recipeTitle: String?
    public var createdAt: Date = Date.now

    public init(text: String, recipeTitle: String? = nil) {
        self.text = text
        self.recipeTitle = recipeTitle
    }
}
