import Foundation

/// A recipe as read from a web page or typed in, before it becomes a
/// SwiftData `Recipe`. Plain values, so it can cross from the network task
/// to the main actor safely.
public struct RecipeDraft: Sendable, Equatable {
    public struct Line: Sendable, Equatable {
        public var text: String
        public var section: String?

        public init(_ text: String, section: String? = nil) {
            self.text = text
            self.section = section
        }
    }

    public var title: String
    public var summary: String = ""
    public var sourceURL: URL?
    public var author: String?
    public var servings: Int?
    public var yieldText: String?
    public var prepTime: TimeInterval?
    public var cookTime: TimeInterval?
    public var totalTime: TimeInterval?
    /// The photo to use: the best of `imageCandidates`.
    public var imageURL: URL?
    /// Every photo the page offers for the recipe, best first: the recipe's
    /// own images (largest first when their size is known), then `og:image`,
    /// then `twitter:image`.
    public var imageCandidates: [URL] = []
    public var ingredients: [Line] = []
    public var steps: [Line] = []
    public var tags: [String] = []

    public init(title: String) {
        self.title = title
    }
}
