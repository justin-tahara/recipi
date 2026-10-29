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
struct LiveImportCheck {
    private static let environment = ProcessInfo.processInfo.environment

    private struct SiteResult: Sendable {
        var url: URL
        var problem: String?
        var detail: String
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["RECIPI_LIVE_CHECK"] == "1", "Set RECIPI_LIVE_CHECK=1 to fetch real recipe sites"))
    func importsEverySiteOnTheList() async throws {
        let urls = try Self.urlList()
        try #require(!urls.isEmpty, "The live check URL list is empty")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        // The offscreen web view has its own test; this run is about the
        // parsers and what sites serve today.
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

        let failures = results.filter { $0.problem != nil }
        try Self.writeReport(results, failures: failures)
        for failure in failures {
            Issue.record("\(failure.url.absoluteString): \(failure.problem ?? "")")
        }
    }

    private static func check(_ url: URL, with importer: RecipeImporter) async -> SiteResult {
        do {
            let draft = try await importer.importRecipe(from: url)
            let detail = "\(draft.title) — \(draft.ingredients.count) ingredients, \(draft.steps.count) steps"
            if draft.ingredients.isEmpty { return SiteResult(url: url, problem: "no ingredients", detail: detail) }
            if draft.steps.isEmpty { return SiteResult(url: url, problem: "no steps", detail: detail) }
            return SiteResult(url: url, problem: nil, detail: detail)
        } catch {
            return SiteResult(url: url, problem: error.localizedDescription, detail: "")
        }
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

    private static func writeReport(_ results: [SiteResult], failures: [SiteResult]) throws {
        guard let path = environment["RECIPI_LIVE_CHECK_REPORT"] else { return }
        var report = "## Live import check\n\n"
        report += "\(results.count - failures.count) of \(results.count) sites imported.\n\n"
        if failures.isEmpty {
            report += "Every site on the list imported.\n"
        } else {
            report += "| Site | Problem |\n| --- | --- |\n"
            for failure in failures {
                report += "| \(failure.url.absoluteString) | \(failure.problem ?? "") |\n"
            }
            report += "\nTo fix one, capture the page with `scripts/capture_fixture.py`, add it as a fixture, then fix the parser.\n"
        }
        report += "\n<details><summary>All results</summary>\n\n"
        for result in results {
            let mark = result.problem == nil ? "ok" : "failed"
            report += "- \(mark): \(result.url.absoluteString) \(result.detail)\n"
        }
        report += "\n</details>\n"
        try report.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }
}
