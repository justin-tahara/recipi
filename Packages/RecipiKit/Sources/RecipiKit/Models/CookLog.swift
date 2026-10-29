import Foundation
import SwiftData

/// One time someone cooked a recipe, with an optional photo of how it came
/// out and a note. Follows the CloudKit rules in Recipe.swift.
@Model
public final class CookLog {
    public var cookedAt: Date = Date.now
    /// Downscaled JPEG, kept out of the database row.
    @Attribute(.externalStorage)
    public var photoData: Data?
    public var note: String = ""
    public var recipe: Recipe?

    public init(cookedAt: Date = .now, photoData: Data? = nil, note: String = "") {
        self.cookedAt = cookedAt
        self.photoData = photoData
        self.note = note
    }
}

extension Recipe {
    /// Newest first.
    public var sortedCookLogs: [CookLog] {
        (cookLogs ?? []).sorted { $0.cookedAt > $1.cookedAt }
    }

    /// Cooks that have a photo, newest first.
    public var cookPhotos: [CookLog] {
        sortedCookLogs.filter { $0.photoData != nil }
    }

    /// Records that this recipe was cooked and updates `lastCookedAt`.
    @discardableResult
    public func logCook(on date: Date = .now, photoData: Data? = nil, note: String = "", in context: ModelContext) -> CookLog {
        let log = CookLog(cookedAt: date, photoData: photoData, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(log)
        cookLogs = (cookLogs ?? []) + [log]
        refreshLastCooked()
        return log
    }

    public func deleteCookLog(_ log: CookLog, in context: ModelContext) {
        cookLogs = (cookLogs ?? []).filter { $0.persistentModelID != log.persistentModelID }
        context.delete(log)
        refreshLastCooked()
    }

    /// Recomputes `lastCookedAt` from the log, e.g. after a sync brought in
    /// cooks from another device.
    public func refreshLastCooked() {
        lastCookedAt = (cookLogs ?? []).map(\.cookedAt).max()
    }
}

/// How the Library orders recipes.
public enum LibrarySort: String, CaseIterable, Identifiable, Sendable, PreferenceValue {
    case title
    case recentlyAdded
    case recentlyCooked
    case notCookedInAWhile

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .title: "Name"
        case .recentlyAdded: "Recently added"
        case .recentlyCooked: "Recently cooked"
        case .notCookedInAWhile: "Not cooked in a while"
        }
    }

    /// What a recipe is sorted by, so the order can be tested without
    /// SwiftData.
    public struct Key: Sendable {
        public var title: String
        public var createdAt: Date
        public var lastCookedAt: Date?

        public init(title: String, createdAt: Date, lastCookedAt: Date?) {
            self.title = title
            self.createdAt = createdAt
            self.lastCookedAt = lastCookedAt
        }
    }

    /// Ties, and recipes never cooked when sorting by cooking, fall back to
    /// the name. Never-cooked recipes go last in both cooking orders.
    public func areInIncreasingOrder(_ lhs: Key, _ rhs: Key) -> Bool {
        let byTitle = lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        switch self {
        case .title:
            return byTitle
        case .recentlyAdded:
            return lhs.createdAt == rhs.createdAt ? byTitle : lhs.createdAt > rhs.createdAt
        case .recentlyCooked, .notCookedInAWhile:
            switch (lhs.lastCookedAt, rhs.lastCookedAt) {
            case let (left?, right?) where left != right:
                return self == .recentlyCooked ? left > right : left < right
            case (.some, nil): return true
            case (nil, .some): return false
            default: return byTitle
            }
        }
    }
}

extension Recipe {
    public var librarySortKey: LibrarySort.Key {
        LibrarySort.Key(title: title, createdAt: createdAt, lastCookedAt: lastCookedAt)
    }
}
