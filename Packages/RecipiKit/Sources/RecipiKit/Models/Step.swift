import Foundation
import SwiftData

@Model
public final class Step {
    public var text: String = ""
    public var order: Int = 0
    /// Optional group heading, e.g. "Make the dough".
    public var section: String?
    public var recipe: Recipe?

    public init(text: String, order: Int, section: String? = nil) {
        self.text = text
        self.order = order
        self.section = section
    }
}
