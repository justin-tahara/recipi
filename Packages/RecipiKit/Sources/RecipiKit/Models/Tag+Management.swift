import Foundation
import SwiftData

extension Tag {
    /// Stored in `kindRaw` when a person chose "no kind", so the vocabulary
    /// doesn't put one back.
    static let noKind = "none"

    /// What the tag is about. A kind the person set wins; otherwise a tag
    /// the vocabulary knows ("Italian", "italiano") has that term's kind.
    public var kind: TagKind? {
        get {
            if let kindRaw { return TagKind(rawValue: kindRaw) }
            return TagVocabulary.term(matching: name)?.kind
        }
        set {
            kindRaw = newValue?.rawValue ?? Self.noKind
        }
    }

    /// The tag as the Library's filters see it.
    public var facet: TagFacet {
        TagFacet(name: name, kind: kind)
    }

    /// `findOrCreate(named:in:)`, recording `kind` on a tag that has none
    /// stored yet. A kind the person chose is left alone.
    public static func findOrCreate(named rawName: String, kind: TagKind?, in context: ModelContext) -> Tag? {
        guard let tag = findOrCreate(named: rawName, in: context) else { return nil }
        if let kind, tag.kindRaw == nil {
            tag.kindRaw = kind.rawValue
        }
        return tag
    }

    /// Another tag with this name, ignoring case.
    public static func existing(named rawName: String, excluding tag: Tag? = nil, in context: ModelContext) -> Tag? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        return all.first { other in
            other.persistentModelID != tag?.persistentModelID
                && other.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    public enum RenameResult: Equatable {
        case renamed
        /// The name belonged to another tag, so this one was merged into it
        /// and deleted.
        case merged(into: Tag)
        case unchanged
        /// The name was blank.
        case invalid
    }

    /// Renames the tag. Renaming to the name of another tag merges the two.
    /// A tag that had a kind keeps it under its new name.
    @discardableResult
    public func rename(to rawName: String, in context: ModelContext) -> RenameResult {
        let newName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return .invalid }
        guard newName != name else { return .unchanged }
        if let other = Self.existing(named: newName, excluding: self, in: context) {
            merge(into: other, in: context)
            return .merged(into: other)
        }
        if kindRaw == nil, let kind {
            kindRaw = kind.rawValue
        }
        name = newName
        touchRecipes()
        return .renamed
    }

    /// Moves this tag's recipes to `target` and deletes this tag. A recipe
    /// that had both ends up with `target` once. `target` takes this tag's
    /// kind and color only where it has none of its own.
    public func merge(into target: Tag, in context: ModelContext) {
        guard target.persistentModelID != persistentModelID else { return }
        let tagged = recipes ?? []
        for recipe in tagged {
            var tags = recipe.tags ?? []
            tags.removeAll { $0.persistentModelID == persistentModelID }
            if !tags.contains(where: { $0.persistentModelID == target.persistentModelID }) {
                tags.append(target)
            }
            recipe.tags = tags
            recipe.updatedAt = .now
        }
        if target.kindRaw == nil { target.kindRaw = kindRaw }
        if target.colorOverride == nil { target.colorOverride = colorOverride }
        context.delete(self)
    }

    /// Removes the tag from every recipe and deletes it. The recipes stay.
    public func delete(in context: ModelContext) {
        let tagged = recipes ?? []
        for recipe in tagged {
            recipe.tags?.removeAll { $0.persistentModelID == persistentModelID }
            recipe.updatedAt = .now
        }
        context.delete(self)
    }

    private func touchRecipes() {
        for recipe in recipes ?? [] {
            recipe.updatedAt = .now
        }
    }
}

extension Recipe {
    /// The recipe's tags as the Library's filters see them.
    public var tagFacets: [TagFacet] {
        (tags ?? []).map(\.facet)
    }
}
