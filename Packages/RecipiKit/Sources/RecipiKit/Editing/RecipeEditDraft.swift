import Foundation
import SwiftData

/// A plain copy of a recipe for the editor to change. The editor works on
/// this copy and only writes it back with `apply(to:in:)` when the person
/// saves, so cancelling leaves the recipe exactly as it was.
///
/// Ingredients and steps are lists of rows where a section heading is a row
/// of its own, the way they're shown while editing. Items belong to the
/// nearest heading above them. A heading left blank means "no section".
public struct RecipeEditDraft: Sendable, Equatable {
    public struct Row: Sendable, Equatable, Identifiable {
        public enum Kind: Sendable, Equatable {
            /// An ingredient line or a step.
            case item
            /// A section heading, e.g. "For the sauce".
            case heading
        }

        public var id: UUID
        public var kind: Kind
        public var text: String

        public init(id: UUID = UUID(), kind: Kind = .item, text: String = "") {
            self.id = id
            self.kind = kind
            self.text = text
        }

        public static func item(_ text: String) -> Row { Row(kind: .item, text: text) }
        public static func heading(_ text: String) -> Row { Row(kind: .heading, text: text) }
    }

    public var title = ""
    public var summary = ""
    /// The source link as typed. See `sourceURL` for the parsed link.
    public var sourceURLText = ""
    public var author = ""
    public var servings: Int?
    public var yieldText = ""
    public var prepTime: TimeInterval?
    public var cookTime: TimeInterval?
    public var totalTime: TimeInterval?
    public var photoData: Data?
    public var notes = ""
    public var isFavorite = false
    public var ingredients: [Row] = []
    public var steps: [Row] = []
    /// Tag names in the order they were added.
    public var tags: [String] = []

    public init() {}

    /// Copies every editable field of `recipe`.
    public init(_ recipe: Recipe) {
        title = recipe.title
        summary = recipe.summary
        sourceURLText = recipe.sourceURL?.absoluteString ?? ""
        author = recipe.author ?? ""
        servings = recipe.servings
        yieldText = recipe.yieldText ?? ""
        prepTime = recipe.prepTime
        cookTime = recipe.cookTime
        totalTime = recipe.totalTime
        photoData = recipe.photoData
        notes = recipe.notes
        isFavorite = recipe.isFavorite
        ingredients = Self.rows(from: recipe.sortedIngredients.map { RecipeDraft.Line($0.text, section: $0.section) })
        steps = Self.rows(from: recipe.sortedSteps.map { RecipeDraft.Line($0.text, section: $0.section) })
        tags = recipe.sortedTags.map(\.name)
    }

    /// Writes the draft back to `recipe`. Ingredient and step sections are
    /// kept, blank rows are dropped, and tags are matched to existing ones.
    public func apply(to recipe: Recipe, in context: ModelContext) {
        recipe.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        // A link that can't be read is left as it was rather than lost; the
        // editor warns about it before saving.
        if isSourceURLValid {
            recipe.sourceURL = sourceURL
        }
        recipe.author = author.nilIfBlank
        recipe.servings = servings.flatMap { $0 > 0 ? $0 : nil }
        recipe.yieldText = yieldText.nilIfBlank
        recipe.prepTime = prepTime.flatMap { $0 > 0 ? $0 : nil }
        recipe.cookTime = cookTime.flatMap { $0 > 0 ? $0 : nil }
        recipe.totalTime = totalTime.flatMap { $0 > 0 ? $0 : nil }
        recipe.photoData = photoData
        recipe.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.isFavorite = isFavorite

        recipe.setIngredients(Self.lines(from: ingredients), in: context)
        recipe.setSteps(Self.lines(from: steps), in: context)

        var seen = Set<String>()
        recipe.tags = tags.compactMap { name -> Tag? in
            guard let tag = Tag.findOrCreate(named: name, in: context), seen.insert(tag.name.lowercased()).inserted else {
                return nil
            }
            return tag
        }
        recipe.updatedAt = .now
    }

    /// True when there's nothing worth keeping, so a new recipe can be
    /// thrown away instead of saved.
    public var isBlank: Bool {
        title.isBlank && summary.isBlank && notes.isBlank && sourceURLText.isBlank && photoData == nil
            && Self.lines(from: ingredients).isEmpty && Self.lines(from: steps).isEmpty
    }

    // MARK: - Source link

    /// The source link, with "https://" added when it was typed without a
    /// scheme. Nil when the field is empty or doesn't hold a usable link.
    public var sourceURL: URL? {
        let text = sourceURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }
        let withScheme = URL(string: text)?.scheme == nil ? "https://" + text : text
        guard let url = URL(string: withScheme), let scheme = url.scheme?.lowercased() else { return nil }
        if scheme == "http" || scheme == "https" {
            guard let host = url.host(), host.contains(".") || host == "localhost" else { return nil }
        }
        return url
    }

    /// False when something is typed in the source field that isn't a link.
    public var isSourceURLValid: Bool {
        sourceURLText.isBlank || sourceURL != nil
    }

    // MARK: - Tags

    /// Adds a tag unless the draft already has it (ignoring case). When a
    /// tag with the same name exists elsewhere, its spelling is used so the
    /// two stay one tag.
    @discardableResult
    public mutating func addTag(_ rawName: String, existing: [String] = []) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !tags.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else {
            return false
        }
        let match = existing.first { $0.caseInsensitiveCompare(name) == .orderedSame }
        tags.append(match ?? name)
        return true
    }

    public mutating func removeTag(_ name: String) {
        tags.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Existing tag names to offer while typing `query`: ones the draft
    /// doesn't have yet, names starting with the query first.
    public func tagSuggestions(for query: String, from existing: [String], limit: Int = 8) -> [String] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set(tags.map { $0.lowercased() })
        let candidates = existing
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .filter { seen.insert($0.lowercased()).inserted }
        guard !query.isEmpty else { return Array(candidates.prefix(limit)) }
        let prefixed = candidates.filter { $0.lowercased().hasPrefix(query.lowercased()) }
        let containing = candidates.filter {
            !$0.lowercased().hasPrefix(query.lowercased()) && $0.localizedCaseInsensitiveContains(query)
        }
        return Array((prefixed + containing).prefix(limit))
    }

    // MARK: - Rows and lines

    /// Turns stored lines into rows, adding a heading row wherever the
    /// section changes.
    public static func rows(from lines: [RecipeDraft.Line]) -> [Row] {
        var rows: [Row] = []
        var current: String?
        for line in lines {
            if line.section != current {
                // Going from a section back to none needs a blank heading
                // to mark where the section ends.
                rows.append(.heading(line.section ?? ""))
                current = line.section
            }
            rows.append(.item(line.text))
        }
        return rows
    }

    /// Turns rows back into lines, giving each item the heading above it.
    /// Blank items, and headings with nothing under them, are dropped.
    public static func lines(from rows: [Row]) -> [RecipeDraft.Line] {
        var lines: [RecipeDraft.Line] = []
        var section: String?
        for row in rows {
            switch row.kind {
            case .heading:
                section = row.text.nilIfBlank
            case .item:
                let text = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                lines.append(RecipeDraft.Line(text, section: section))
            }
        }
        return lines
    }
}

extension [RecipeEditDraft.Row] {
    /// Inserts an empty row after the row with `id`, or at the end, and
    /// returns its id.
    @discardableResult
    public mutating func insertRow(_ kind: RecipeEditDraft.Row.Kind = .item, after id: UUID? = nil) -> UUID {
        let row = RecipeEditDraft.Row(kind: kind)
        if let id, let index = firstIndex(where: { $0.id == id }) {
            insert(row, at: index + 1)
        } else {
            append(row)
        }
        return row.id
    }

    /// When the row's text holds line breaks (Return was pressed, or several
    /// lines were pasted), keeps the first line in the row and puts each
    /// following line in a new item row below it. Returns the id of the row
    /// the cursor should move to, or nil if nothing changed.
    @discardableResult
    public mutating func splitLines(at id: UUID) -> UUID? {
        guard let index = firstIndex(where: { $0.id == id }), self[index].text.contains(where: \.isNewline) else {
            return nil
        }
        var pieces = self[index].text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        let first = pieces.removeFirst()
        // Pressing Return at the end leaves one empty piece: that's a new,
        // empty row. Other empty pieces from pasted text are dropped.
        let isReturnAtEnd = pieces.count == 1 && pieces[0].isEmpty
        let rest = isReturnAtEnd ? [""] : pieces.filter { !$0.isBlank }

        self[index].text = first
        let newRows = rest.map { RecipeEditDraft.Row(kind: .item, text: $0.trimmingCharacters(in: .whitespaces)) }
        insert(contentsOf: newRows, at: index + 1)
        return newRows.last?.id ?? id
    }

    /// Turns an item into a heading or a heading into an item. Imported
    /// recipes sometimes read a heading like "For the sauce:" as an
    /// ingredient; this fixes that, dropping the trailing colon.
    public mutating func toggleKind(of id: UUID) {
        guard let index = firstIndex(where: { $0.id == id }) else { return }
        switch self[index].kind {
        case .item:
            self[index].kind = .heading
            var text = self[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasSuffix(":") { text.removeLast() }
            self[index].text = text
        case .heading:
            self[index].kind = .item
        }
    }

    public mutating func removeRow(_ id: UUID) {
        removeAll { $0.id == id }
    }

    /// Moves rows like a list's drag to reorder: `destination` is an index
    /// in the list before the move.
    public mutating func moveRows(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { self[$0] }
        let shift = source.filter { $0 < destination }.count
        for index in source.sorted(by: >) {
            remove(at: index)
        }
        insert(contentsOf: moving, at: Swift.min(Swift.max(destination - shift, 0), count))
    }

    /// Moves one row up (negative) or down (positive), for VoiceOver's
    /// move actions.
    public mutating func moveRow(_ id: UUID, by offset: Int) {
        guard let index = firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard indices.contains(target) else { return }
        let row = remove(at: index)
        insert(row, at: target)
    }
}

extension String {
    fileprivate var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    fileprivate var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
