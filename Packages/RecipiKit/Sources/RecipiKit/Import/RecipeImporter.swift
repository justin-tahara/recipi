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
/// the fallback heuristics. When neither finds a recipe it follows a meta
/// refresh or an AMP page's canonical link, and as a last resort renders the
/// page offscreen for sites that only add their recipe data with JavaScript.
public struct RecipeImporter: Sendable {
    private let session: URLSession
    private let rendersJavaScript: Bool

    /// - Parameter rendersJavaScript: Whether to load the page in an offscreen
    ///   web view when the HTML as served has no recipe. On by default; tests
    ///   and the nightly live check turn it off.
    public init(session: URLSession = .shared, rendersJavaScript: Bool = true) {
        self.session = session
        self.rendersJavaScript = rendersJavaScript
    }

    /// A page can send us on to another one at most this many times.
    private static let maxFollowUps = 2

    public func importRecipe(from url: URL) async throws -> RecipeDraft {
        // URLSession follows HTTP redirects itself; `page.url` is where it
        // ended up.
        var page = try await fetchPage(url)
        var visited: Set<URL> = [url, page.url]
        for hop in 0...Self.maxFollowUps {
            if let draft = try? Self.parse(html: page.html, sourceURL: page.url) {
                return draft
            }
            guard hop < Self.maxFollowUps,
                  let next = Self.followUpURL(in: page.html, pageURL: page.url),
                  visited.insert(next).inserted,
                  let nextPage = try? await fetchPage(next) else { break }
            visited.insert(nextPage.url)
            page = nextPage
        }
        if rendersJavaScript, let draft = await Self.renderedRecipe(at: page.url) {
            return draft
        }
        throw RecipeImportError.noRecipeFound
    }

    public static func parse(html: String, sourceURL: URL?) throws -> RecipeDraft {
        if var draft = SchemaRecipeParser.parse(html: html, sourceURL: sourceURL) {
            // JSON-LD has no ingredient groups, but the recipe card on the
            // same page often does.
            if let markup = FallbackRecipeParser.parse(html: html, sourceURL: sourceURL) {
                draft.ingredients = withSections(draft.ingredients, from: markup.ingredients)
                draft.steps = withSections(draft.steps, from: markup.steps)
            }
            return draft
        }
        if let draft = FallbackRecipeParser.parse(html: html, sourceURL: sourceURL) {
            return draft
        }
        throw RecipeImportError.noRecipeFound
    }

    /// `lines` with the section headings of `markup`, when the JSON-LD had
    /// none and both lists are the same recipe, line for line.
    static func withSections(_ lines: [RecipeDraft.Line], from markup: [RecipeDraft.Line]) -> [RecipeDraft.Line] {
        guard lines.count == markup.count,
              lines.allSatisfy({ $0.section == nil }),
              markup.contains(where: { $0.section != nil }) else { return lines }
        return zip(lines, markup).map { line, marked in
            RecipeDraft.Line(line.text, section: marked.section)
        }
    }

    /// Downloads the recipe's photo, if it has one. Failure is not fatal.
    public func fetchImage(for draft: RecipeDraft) async -> Data? {
        guard let imageURL = draft.imageURL else { return nil }
        return try? await session.data(from: imageURL).0
    }

    // MARK: - Fetching

    private struct Page {
        var html: String
        var url: URL
    }

    private func fetchPage(_ url: URL) async throws -> Page {
        var request = URLRequest(url: url)
        // Some recipe sites serve a stripped page to unknown clients.
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await session.data(for: request)
        guard let html = Self.decodePage(data, encodingName: response.textEncodingName) else {
            throw RecipeImportError.unreadablePage
        }
        return Page(html: html, url: response.url ?? url)
    }

    /// The page as text, in the charset the server or the page declares,
    /// falling back to UTF-8 and then Latin-1.
    static func decodePage(_ data: Data, encodingName: String?) -> String? {
        var declared = encodingName
        if declared == nil {
            let head = String(decoding: data.prefix(2_048), as: UTF8.self)
            declared = HTMLText.captures(of: #"<meta[^>]*charset\s*=\s*["']?([\w-]+)"#, in: head).first
        }
        if let declared, let encoding = encoding(named: declared), let html = String(data: data, encoding: encoding) {
            return html
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    private static func encoding(named name: String) -> String.Encoding? {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }

    /// Where a page without recipe data sends us instead: a meta refresh
    /// (some link shorteners use one), or an AMP page's canonical page.
    static func followUpURL(in html: String, pageURL: URL) -> URL? {
        let target = HTMLText.metaRefreshTarget(in: html)
            ?? (isAMP(html, url: pageURL) ? HTMLText.linkHref(rel: "canonical", in: html) : nil)
        guard let target,
              let url = URL(string: target, relativeTo: pageURL)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url != pageURL else { return nil }
        return url
    }

    /// AMP pages mark their `<html>` tag with `amp` or `⚡`; some are only
    /// recognisable by an `/amp` path.
    static func isAMP(_ html: String, url: URL) -> Bool {
        if html.range(of: #"(?i)<html(?:\s[^>]*)?\s(?:amp|⚡)(?=[\s=/>])"#, options: .regularExpression) != nil {
            return true
        }
        let path = url.path().lowercased()
        return path.hasSuffix("/amp") || path.hasSuffix("/amp/") || path.contains("/amp/")
    }

    private static func renderedRecipe(at url: URL) async -> RecipeDraft? {
        #if canImport(WebKit)
        return await RenderedPageReader.recipe(at: url)
        #else
        return nil
        #endif
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
