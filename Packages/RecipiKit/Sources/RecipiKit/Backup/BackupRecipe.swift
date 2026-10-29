import Foundation

/// One recipe as it goes into a backup or comes out of one. Plain values, so
/// it can be built on the main actor from a SwiftData `Recipe` and written
/// to a file on another task. `Recipe+Backup.swift` maps it to and from the
/// model; `RecipiBackup` turns it into files.
public struct BackupRecipe: Sendable, Equatable, Identifiable {
    /// The recipe's stable ID (`Recipe.uuid`).
    public var id: UUID
    public var title: String
    public var summary: String = ""
    public var sourceURL: URL?
    public var author: String?
    public var servings: Int?
    public var yieldText: String?
    public var prepTime: TimeInterval?
    public var cookTime: TimeInterval?
    public var totalTime: TimeInterval?
    public var notes: String = ""
    public var isFavorite: Bool = false
    public var createdAt: Date
    public var updatedAt: Date
    /// In order, each with its section heading.
    public var ingredients: [RecipeDraft.Line] = []
    /// In order, each with its section heading.
    public var steps: [RecipeDraft.Line] = []
    public var tags: [String] = []
    /// The photo's bytes exactly as recipi stored them (usually JPEG).
    public var photoData: Data?

    public init(id: UUID = UUID(), title: String, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
