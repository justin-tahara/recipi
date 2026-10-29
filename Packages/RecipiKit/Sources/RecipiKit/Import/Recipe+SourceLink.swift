import Foundation
import SwiftData

extension Recipe {
    /// A saved recipe imported from the same page as `url`, if there is one,
    /// so an import can say "already saved" instead of adding a copy.
    /// Links that differ only in `http`/`https`, `www.`, tracking
    /// parameters, a trailing slash or a fragment are the same page (see
    /// `SharedLink.sourceKey(for:)`). The oldest match wins.
    public static func saved(from url: URL, in context: ModelContext) throws -> Recipe? {
        let key = SharedLink.sourceKey(for: url)
        let descriptor = FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor).first { recipe in
            recipe.sourceURL.map { SharedLink.sourceKey(for: $0) } == key
        }
    }
}
