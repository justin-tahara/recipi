import Foundation
import SwiftData

public enum RecipeImportError: LocalizedError, Equatable {
    case unreadablePage
    case noRecipeFound
    /// The site answered with an error status or a bot check instead of the
    /// page (403, 429, a Cloudflare "Just a moment" page and the like).
    case blockedBySite
    /// The site says the page doesn't exist (404 or 410).
    case pageNotFound
    /// The site had a problem of its own (a 5xx status).
    case siteUnavailable
    /// The link is a file, like a PDF or a photo, not a web page.
    case notAWebPage
    /// The device has no internet connection.
    case offline
    /// The site took too long to answer.
    case timedOut
    /// The site couldn't be reached: an unknown host, a refused or broken
    /// connection, a certificate problem.
    case siteUnreachable

    public var errorDescription: String? {
        switch self {
        case .unreadablePage: "That page couldn't be read."
        case .noRecipeFound: "No recipe was found on that page. You can still add it by hand."
        case .blockedBySite: "That site didn't let recipi read the page. Try again in a little while, or add the recipe by hand."
        case .pageNotFound: "That page wasn't found. Check that the link is complete and try again."
        case .siteUnavailable: "That site isn't working right now. Try again in a little while."
        case .notAWebPage: "That link opens a file, not a web page. recipi can import recipes from web pages."
        case .offline: "You're offline. Connect to the internet and try again."
        case .timedOut: "That site took too long to answer. Try again in a moment."
        case .siteUnreachable: "recipi couldn't reach that site. Check the link and your connection, then try again."
        }
    }

    /// Whether loading the page in a web view might still get the recipe:
    /// a browser can pass some bot checks that a plain request can't.
    var mightRenderPastIt: Bool {
        switch self {
        case .noRecipeFound, .blockedBySite: true
        default: false
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
        var trace = ImportTrace()
        return try await importRecipe(from: url, trace: &trace)
    }

    /// Imports `url`, noting in `trace` what was fetched and why it failed.
    /// The nightly live check reports from the trace.
    func importRecipe(from url: URL, trace: inout ImportTrace) async throws -> RecipeDraft {
        // URLSession follows HTTP redirects itself; `page.url` is where it
        // ended up.
        var page = try await fetchPage(url, trace: &trace)
        var visited: Set<URL> = [url, page.url]
        for hop in 0...Self.maxFollowUps {
            // Parse whatever came back, even with an error status: if a
            // recipe is there, it's the recipe.
            if let draft = try? Self.parse(html: page.html, sourceURL: page.url) {
                return draft
            }
            guard hop < Self.maxFollowUps,
                  let next = Self.followUpURL(in: page.html, pageURL: page.url),
                  visited.insert(next).inserted,
                  let nextPage = try? await fetchPage(next, trace: &trace) else { break }
            visited.insert(nextPage.url)
            page = nextPage
        }
        let problem = PageCheck.problem(status: page.status, html: page.html)
        trace.reason = problem?.reason
        // A web view runs the page's scripts, which adds recipes that only
        // exist after JavaScript and can get past some bot checks.
        if rendersJavaScript, problem?.error.mightRenderPastIt ?? true,
           let draft = await Self.renderedRecipe(at: page.url) {
            trace.usedRenderedPage = true
            return draft
        }
        throw problem?.error ?? RecipeImportError.noRecipeFound
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

    /// Downloads the recipe's photo, if it has one, ready to save: at most
    /// 2048 px on its long edge. If the best photo won't load, the next
    /// couple of candidates are tried. Failure is not fatal.
    public func fetchImage(for draft: RecipeDraft) async -> Data? {
        let candidates = draft.imageCandidates.isEmpty ? [draft.imageURL].compactMap { $0 } : draft.imageCandidates
        for url in candidates.prefix(3) {
            if let photo = await fetchPhoto(at: url) { return photo.data }
        }
        return nil
    }

    /// Downloads one photo and prepares it for saving and previewing.
    /// Returns nil if it won't load or isn't an image.
    public func fetchPhoto(at url: URL) async -> ImportedPhoto? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        guard let result = try? await session.data(for: request) else { return nil }
        let (data, response) = result
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        // Resizing decodes the image, so do it once for the saved copy and
        // make the small preview from that.
        guard let saved = RecipePhotoProcessor.prepare(data),
              let preview = RecipePhotoProcessor.prepare(saved, maxPixelSize: RecipePhotoProcessor.previewPixelSize, quality: 0.7) else {
            return nil
        }
        return ImportedPhoto(url: url, data: saved, preview: preview)
    }

    // MARK: - Fetching

    private struct Page {
        var html: String
        var url: URL
        var status: Int?
    }

    private func fetchPage(_ url: URL, trace: inout ImportTrace) async throws -> Page {
        let url = Self.upgradingToHTTPS(url)
        let request = Self.pageRequest(for: url)
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            trace.networkError = "\(url.absoluteString): \(error.localizedDescription)"
            throw Self.importError(for: error)
        }
        let (data, response) = result
        let status = (response as? HTTPURLResponse)?.statusCode
        let finalURL = response.url ?? url
        trace.fetches.append(ImportTrace.Fetch(
            requestedURL: url, finalURL: finalURL, status: status, byteCount: data.count, mimeType: response.mimeType
        ))
        let succeeded = status.map { (200..<300).contains($0) } ?? true
        if succeeded, let verdict = PageCheck.fileInsteadOfPage(mimeType: response.mimeType, data: data) {
            trace.reason = verdict.reason
            throw verdict.error
        }
        // An error page that won't decode is still an error page; its
        // status says what went wrong.
        guard let html = Self.decodePage(data, encodingName: response.textEncodingName) ?? (succeeded ? nil : "") else {
            throw RecipeImportError.unreadablePage
        }
        return Page(html: html, url: finalURL, status: status)
    }

    /// `url` with `https` in place of `http`. iOS refuses plain-http loads
    /// in the app (App Transport Security), and nearly every recipe site
    /// serves the same page over https.
    static func upgradingToHTTPS(_ url: URL) -> URL {
        guard url.scheme?.lowercased() == "http",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.scheme = "https"
        if components.port == 80 { components.port = nil }
        return components.url ?? url
    }

    /// A request that looks like Safari on an iPhone opening the page. Some
    /// sites serve a stripped page, or a bot check, to clients that don't.
    static func pageRequest(for url: URL, languages: [String] = Locale.preferredLanguages) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(acceptLanguage(for: languages), forHTTPHeaderField: "Accept-Language")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("none", forHTTPHeaderField: "Sec-Fetch-Site")
        return request
    }

    /// Mobile Safari's user agent. Safari has reported iOS 18.6 here since
    /// iOS 26, so this doesn't need to follow each release.
    static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1"

    /// An `Accept-Language` value for the person's languages, most preferred
    /// first, each followed by its base language: `["en-GB", "de"]` becomes
    /// `en-GB,en;q=0.9,de;q=0.8`.
    static func acceptLanguage(for languages: [String]) -> String {
        var tags: [String] = []
        for language in languages {
            let tag = language.replacingOccurrences(of: "_", with: "-")
            let base = String(tag.prefix { $0 != "-" })
            for candidate in [tag, base] where !candidate.isEmpty && !tags.contains(candidate) {
                tags.append(candidate)
            }
        }
        if tags.isEmpty { tags = ["en-US", "en"] }
        return tags.prefix(6).enumerated().map { index, tag in
            index == 0 ? tag : "\(tag);q=0.\(10 - index)"
        }.joined(separator: ",")
    }

    /// A network failure in words the person can act on. Cancellation is
    /// passed on as it is.
    static func importError(for error: any Error) -> any Error {
        guard let urlError = error as? URLError else { return error }
        switch urlError.code {
        case .cancelled:
            return urlError
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            return RecipeImportError.offline
        case .timedOut:
            return RecipeImportError.timedOut
        default:
            return RecipeImportError.siteUnreachable
        }
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
        return try save(draft, photoData: photoData, into: context)
    }

    /// Saves a draft that was already imported, with the photo the person
    /// picked (or none).
    @MainActor
    @discardableResult
    public func save(_ draft: RecipeDraft, photoData: Data?, into context: ModelContext) throws -> Recipe {
        let recipe = Recipe.insert(from: draft, photoData: photoData, into: context)
        try context.save()
        return recipe
    }
}

/// What one import fetched and why it stopped, for the nightly live check's
/// report. Nothing in the app keeps or sends it.
struct ImportTrace: Sendable {
    struct Fetch: Sendable {
        var requestedURL: URL
        /// Where HTTP redirects ended up.
        var finalURL: URL
        var status: Int?
        var byteCount: Int
        var mimeType: String?
    }

    /// Every page fetched, in order: the link, then any meta refresh or AMP
    /// canonical it led to.
    var fetches: [Fetch] = []
    /// The request that failed without an HTTP answer, and how.
    var networkError: String?
    /// What told the importer the site wouldn't show the page.
    var reason: String?
    /// Whether the recipe came from the offscreen web view.
    var usedRenderedPage = false
}
