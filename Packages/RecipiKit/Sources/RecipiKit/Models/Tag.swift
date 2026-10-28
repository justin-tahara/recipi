import Foundation
import SwiftData

@Model
public final class Tag {
    public var name: String = ""
    public var recipes: [Recipe]? = []

    public init(name: String) {
        self.name = name
    }
}

extension Tag {
    /// Returns the existing tag with this name (case-insensitive), or inserts
    /// a new one. CloudKit forbids unique constraints, so we dedupe by hand.
    public static func findOrCreate(named rawName: String, in context: ModelContext) -> Tag? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let existing = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return match
        }
        let tag = Tag(name: name)
        context.insert(tag)
        return tag
    }
}
