import Foundation

/// A tag as the Library's filters see it: a name and, when known, a kind.
public struct TagFacet: Sendable, Hashable, Identifiable {
    public var name: String
    public var kind: TagKind?

    public init(name: String, kind: TagKind? = nil) {
        self.name = name
        self.kind = kind
    }

    public var id: String { "\(kind?.rawValue ?? "tag"):\(name.lowercased())" }

    /// True when the facet is a cuisine group like "Asian".
    public var isGroup: Bool {
        TagVocabulary.term(named: name)?.isGroup == true
    }
}

/// The Library's tag filter: any number of chips. Chips of a kind a recipe
/// usually has one of (cuisine, meal) match if any of them does; chips of
/// other kinds must all match. "Italian" + "Japanese" + "Dinner" shows
/// Italian or Japanese dinners; "Vegan" + "Quick" shows quick vegan ones.
/// A group chip like "Asian" matches each of its cuisines.
public struct TagFilter: Sendable, Equatable {
    public var selection: Set<TagFacet> = []

    public init(selection: Set<TagFacet> = []) {
        self.selection = selection
    }

    public var isEmpty: Bool { selection.isEmpty }

    public func isSelected(_ facet: TagFacet) -> Bool {
        selection.contains(facet)
    }

    public mutating func toggle(_ facet: TagFacet) {
        if selection.remove(facet) == nil {
            selection.insert(facet)
        }
    }

    public mutating func clear() {
        selection.removeAll()
    }

    /// Drops chips that no longer exist, e.g. after a tag was deleted.
    public mutating func keep(only available: [TagFacet]) {
        selection.formIntersection(available)
    }

    public func matches(_ tags: [TagFacet]) -> Bool {
        guard !selection.isEmpty else { return true }
        let byKind = Dictionary(grouping: selection, by: \.kind)
        for (kind, chips) in byKind {
            let hits = chips.map { chip in
                tags.contains { TagVocabulary.chip(named: chip.name, matchesTagNamed: $0.name) }
            }
            let anyOf = kind?.filtersAsAnyOf ?? false
            if anyOf ? !hits.contains(true) : hits.contains(false) {
                return false
            }
        }
        return true
    }
}

/// A row of filter chips for one kind of tag.
public struct TagFilterSection: Sendable, Equatable, Identifiable {
    /// Nil for tags without a kind.
    public var kind: TagKind?
    public var chips: [TagFacet]

    public var id: String { kind?.rawValue ?? "tags" }

    public var title: String { kind?.title ?? "Tags" }

    /// The chips to offer for these tags, one section per kind in the
    /// vocabulary's order, plain tags last. Within a kind, vocabulary terms
    /// come in the vocabulary's order (groups like "Asian" first, shown
    /// whenever one of their cuisines is used), then the person's own tags
    /// alphabetically.
    public static func sections(for tags: [TagFacet]) -> [TagFilterSection] {
        var unique: [TagFacet] = []
        var seen = Set<String>()
        for tag in tags where seen.insert(TagVocabulary.normalized(tag.name)).inserted {
            unique.append(tag)
        }

        var sections: [TagFilterSection] = []
        var kinds: [TagKind?] = TagKind.allCases.map { Optional($0) }
        kinds.append(nil)
        for kind in kinds {
            var chips = unique.filter { $0.kind == kind }
            if kind == .cuisine {
                for group in TagVocabulary.terms(of: .cuisine) where group.isGroup {
                    let key = TagVocabulary.normalized(group.name)
                    let isUsed = unique.contains { tag in
                        tag.kind == .cuisine && TagVocabulary.chip(named: group.name, matchesTagNamed: tag.name)
                    }
                    if isUsed, !chips.contains(where: { TagVocabulary.normalized($0.name) == key }) {
                        chips.append(TagFacet(name: group.name, kind: .cuisine))
                    }
                }
            }
            guard !chips.isEmpty else { continue }
            sections.append(TagFilterSection(kind: kind, chips: chips.sorted(by: chipOrder)))
        }
        return sections
    }

    private static func chipOrder(_ lhs: TagFacet, _ rhs: TagFacet) -> Bool {
        let left = vocabularyPosition(lhs), right = vocabularyPosition(rhs)
        switch (left, right) {
        case let (left?, right?): return left < right
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func vocabularyPosition(_ facet: TagFacet) -> Int? {
        guard let term = TagVocabulary.term(matching: facet.name) else { return nil }
        return TagVocabulary.terms.firstIndex(of: term)
    }
}
