import Foundation
import SwiftData

public enum RecipeImportError: LocalizedError, Equatable {
    case unreadablePage
    case noRecipeFound

    public var errorDescription: String? {
        switch self {
        case .unreadablePage: "That page couldn't be read."
        case .noRecipeFound: "No recipe was found on that page. You can still add it by hand."
        }
    }
}

/// Fetches a page and turns it into a `RecipeDraft`: JSON-LD first, then
/// the fallback heuristics.
public struct RecipeImporter: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func importRecipe(from url: URL) async throws -> RecipeDraft {
        var request = URLRequest(url: url)
        // Some recipe sites serve a stripped page to unknown clients.
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await session.data(for: request)
        let pageURL = response.url ?? url
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw RecipeImportError.unreadablePage
        }
        return try Self.parse(html: html, sourceURL: pageURL)
    }

    public static func parse(html: String, sourceURL: URL?) throws -> RecipeDraft {
        if let draft = SchemaRecipeParser.parse(html: html, sourceURL: sourceURL) {
            return draft
        }
        if let draft = FallbackRecipeParser.parse(html: html, sourceURL: sourceURL) {
            return draft
        }
        throw RecipeImportError.noRecipeFound
    }

    /// Downloads the recipe's photo, if it has one. Failure is not fatal.
    public func fetchImage(for draft: RecipeDraft) async -> Data? {
        guard let imageURL = draft.imageURL else { return nil }
        return try? await session.data(from: imageURL).0
    }
}

extension RecipeImporter {
    /// Imports the page at `url` and saves it as a new recipe. Shared by the
    /// app's "Import from link" sheet and the Safari share extension.
    @MainActor
    @discardableResult
    public func saveRecipe(from url: URL, into context: ModelContext) async throws -> Recipe {
        let draft = try await importRecipe(from: url)
        let photoData = await fetchImage(for: draft)
        let recipe = Recipe.insert(from: draft, photoData: photoData, into: context)
        try context.save()
        return recipe
    }
}
