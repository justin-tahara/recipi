import Foundation
import Testing
@testable import RecipiKit

/// Imports real recipe pages over the network, to catch sites that change
/// their markup. Run nightly by `.github/workflows/live-import-check.yml`;
/// skipped everywhere else, so `swift test` never touches the network.
///
/// - `RECIPI_LIVE_CHECK=1` turns it on.
/// - `RECIPI_LIVE_CHECK_URLS` is the URL list (default
///   `scripts/live-check-urls.txt`): one URL per line, `#` for comments.
/// - `RECIPI_LIVE_CHECK_REPORT`, if set, is where a Markdown summary goes.
///
/// Only parser failures fail the run: a page that came back and didn't give
/// a full recipe. A site that turned the runner away (a 4xx, a bot check),
/// a page that's gone, a site error or a network error is listed as a
/// warning, since it says nothing about the parsers. Pages that fail as
/// served get a second try in the offscreen web view, as on a device.
struct LiveImportCheck {
    private static let environment = ProcessInfo.processInfo.environment

    /// How one site went, from the importer's point of view.
    enum Outcome: String, Sendable {
        case parsed = "parsed"
        /// Only the offscreen web view got the recipe, as it would on a device.
        case parsedAfterRender = "parsed after render"
        /// Imported, but with no ingredients or no steps.
        case incomplete = "incomplete"
        case noRecipeFound = "no recipe found"
        case unreadable = "unreadable page"
        /// A 4xx, a bot check or an empty page. Says nothing about the
        /// parsers: sites often turn away a data-centre runner.
        case blockedBySite = "blocked by site"
        case pageNotFound = "page not found"
        case siteError = "site error"
        case notAWebPage = "not a web page"
        case networkError = "network error"

        init(_ error: any Error) {
            switch error as? RecipeImportError {
            case .noRecipeFound?: self = .noRecipeFound
            case .unreadablePage?: self = .unreadable
            case .blockedBySite?: self = .blockedBySite
            case .pageNotFound?: self = .pageNotFound
            case .siteUnavailable?: self = .siteError
            case .notAWebPage?: self = .notAWebPage
            case .offline?, .timedOut?, .siteUnreachable?, nil: self = .networkError
            }
        }

        /// Fails the run: the parsers had the page and got it wrong.
        var isFailure: Bool {
            [.incomplete, .noRecipeFound, .unreadable].contains(self)
        }

        /// Worth a look, but not the parsers' fault.
        var isWarning: Bool {
            [.blockedBySite, .pageNotFound, .siteError, .notAWebPage, .networkError].contains(self)
        }

        /// Whether a browser might still get the recipe.
        var mightRender: Bool {
            self == .noRecipeFound || self == .blockedBySite
        }
    }

    struct SiteResult: Sendable {
        var url: URL
        var outcome: Outcome
        var trace: ImportTrace
        /// The recipe's title and counts, or what went wrong.
        var detail: String
        /// When the web view was tried after a failure: what it got.
        var renderNote: String?
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["RECIPI_LIVE_CHECK"] == "1", "Set RECIPI_LIVE_CHECK=1 to fetch real recipe sites"))
    func importsEverySiteOnTheList() async throws {
        let urls = try Self.urlList()
        try #require(!urls.isEmpty, "The live check URL list is empty")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        // The parsers see the page as served first; the web view only gets a
        // go at pages that failed, so the report can tell the two apart.
        let importer = RecipeImporter(session: URLSession(configuration: configuration), rendersJavaScript: false)

        var results: [SiteResult] = []
        // A few at a time, so the run is quick without hammering anyone.
        for batch in stride(from: 0, to: urls.count, by: 4).map({ Array(urls[$0..<min($0 + 4, urls.count)]) }) {
            let batchResults = await withTaskGroup(of: SiteResult.self, returning: [SiteResult].self) { group in
                for url in batch {
                    group.addTask { await Self.check(url, with: importer) }
                }
                var collected: [SiteResult] = []
                for await result in group { collected.append(result) }
                return collected
            }
            results += batchResults
        }
        results.sort { $0.url.absoluteString < $1.url.absoluteString }

        let report = Self.report(results)
        print(report)
        if let path = Self.environment["RECIPI_LIVE_CHECK_REPORT"] {
            try report.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        }
        for result in results where result.outcome.isFailure {
            Issue.record("\(result.url.absoluteString): \(result.outcome.rawValue) \(result.detail)")
        }
    }

    private static func check(_ url: URL, with importer: RecipeImporter) async -> SiteResult {
        var trace = ImportTrace()
        do {
            let draft = try await importer.importRecipe(from: url, trace: &trace)
            let detail = summary(of: draft)
            let complete = !draft.ingredients.isEmpty && !draft.steps.isEmpty
            return SiteResult(url: url, outcome: complete ? .parsed : .incomplete, trace: trace, detail: detail)
        } catch {
            var result = SiteResult(url: url, outcome: Outcome(error), trace: trace, detail: error.localizedDescription)
            if result.outcome.mightRender {
                let pageURL = trace.fetches.last?.finalURL ?? url
                if let draft = await rendered(pageURL) {
                    result.renderNote = "web view got it: \(summary(of: draft))"
                    if !draft.ingredients.isEmpty, !draft.steps.isEmpty {
                        result.outcome = .parsedAfterRender
                        result.detail = summary(of: draft)
                    }
                } else {
                    result.renderNote = "web view found no recipe either"
                }
            }
            return result
        }
    }

    private static func summary(of draft: RecipeDraft) -> String {
        "\(draft.title) — \(draft.ingredients.count) ingredients, \(draft.steps.count) steps"
    }

    /// The recipe the offscreen web view reads from `url`, where WebKit is
    /// available (macOS runners have it). A device does this on its own
    /// after the same failures.
    private static func rendered(_ url: URL) async -> RecipeDraft? {
        #if canImport(WebKit)
        return await RenderedPageReader.recipe(at: url, timeout: .seconds(15))
        #else
        return nil
        #endif
    }

    private static func urlList() throws -> [URL] {
        let path = environment["RECIPI_LIVE_CHECK_URLS"].map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // RecipiKitTests
                .deletingLastPathComponent() // Tests
                .deletingLastPathComponent() // RecipiKit
                .deletingLastPathComponent() // Packages
                .deletingLastPathComponent() // repository root
                .appending(path: "scripts/live-check-urls.txt")
        return try String(contentsOf: path, encoding: .utf8)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .compactMap(URL.init(string:))
    }

    static func report(_ results: [SiteResult]) -> String {
        let failures = results.filter { $0.outcome.isFailure }
        let warnings = results.filter { $0.outcome.isWarning }
        let imported = results.filter { $0.outcome == .parsed || $0.outcome == .parsedAfterRender }

        var report = "## Live import check\n\n"
        report += "\(imported.count) of \(results.count) sites imported"
        report += ", \(failures.count) failed and \(warnings.count) couldn't be checked.\n\n"

        if failures.isEmpty {
            report += "No parser failures.\n"
        } else {
            report += "### Failures\n\nThe page came back and the parsers didn't get a full recipe from it.\n\n"
            report += table(failures)
            report += "\nTo fix one, capture the page with `scripts/capture_fixture.py`, add it as a fixture, then fix the parser.\n"
        }

        if !warnings.isEmpty {
            report += "\n### Couldn't check (not failures)\n\n"
            report += "These say nothing about the parsers. Sites often turn away a data-centre runner that a phone gets through; "
            report += "try the link on a device. Replace a page that's gone (404) in `scripts/live-check-urls.txt`.\n\n"
            report += table(warnings)
        }

        let rendered = results.filter { $0.outcome == .parsedAfterRender }
        if !rendered.isEmpty {
            report += "\n### Imported only after rendering\n\nThe page as served had no recipe; the offscreen web view found one, as it would on a device.\n\n"
            report += table(rendered)
        }

        report += "\n<details><summary>All results</summary>\n\n"
        report += table(results)
        report += "\n</details>\n"
        return report
    }

    /// One row per site: what happened, every HTTP status on the way, where
    /// redirects ended, how many bytes came back and why it stopped.
    private static func table(_ results: [SiteResult]) -> String {
        var table = "| Site | Result | HTTP | Final URL | Bytes | Detail |\n| --- | --- | --- | --- | --- | --- |\n"
        for result in results {
            let fetches = result.trace.fetches
            let statuses = fetches.isEmpty ? "–" : fetches.map { fetch in fetch.status.map { String($0) } ?? "?" }.joined(separator: " → ")
            let finalURL = fetches.last.map { $0.finalURL == result.url ? "same" : $0.finalURL.absoluteString } ?? "–"
            let bytes = fetches.isEmpty ? "–" : fetches.map { String($0.byteCount) }.joined(separator: " → ")
            var detail = result.detail
            if let mime = fetches.last?.mimeType, !mime.hasPrefix("text/html") { detail += " (\(mime))" }
            if let reason = result.trace.reason { detail += " [\(reason)]" }
            if let error = result.trace.networkError { detail += " [\(error)]" }
            if let note = result.renderNote { detail += " Render: \(note)." }
            let cells = [result.url.absoluteString, result.outcome.rawValue, statuses, finalURL, bytes, detail]
            table += "| " + cells.map(cell).joined(separator: " | ") + " |\n"
        }
        return table
    }

    private static func cell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }
}
