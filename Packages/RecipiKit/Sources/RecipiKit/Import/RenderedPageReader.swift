#if canImport(WebKit)
import Foundation
import WebKit

/// Loads a page in an offscreen web view and reads the recipe from the DOM
/// once its scripts have run. A few sites only add their JSON-LD with
/// JavaScript, so the HTML as served has nothing for the parsers.
///
/// The web view is never put on screen, keeps no cookies or storage, and is
/// thrown away afterwards. Like the rest of the import, it runs on device.
@MainActor
public enum RenderedPageReader {
    /// How long to wait for the page's scripts to produce a recipe.
    public nonisolated static let defaultTimeout: Duration = .seconds(12)

    /// Loads `url` and returns the recipe its rendered DOM describes.
    public static func recipe(at url: URL, timeout: Duration = defaultTimeout) async -> RecipeDraft? {
        await read(sourceURL: url, timeout: timeout) { webView in
            webView.load(URLRequest(url: url))
        }
    }

    /// Renders `html` as if it were served from `baseURL`. Used by tests.
    public static func recipe(inHTML html: String, baseURL: URL?, timeout: Duration = defaultTimeout) async -> RecipeDraft? {
        await read(sourceURL: baseURL, timeout: timeout) { webView in
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    private static func read(sourceURL: URL?, timeout: Duration, load: (WKWebView) -> Void) async -> RecipeDraft? {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        defer { webView.stopLoading() }
        load(webView)

        // Scripts can add the JSON-LD well after the load event, so poll the
        // DOM rather than waiting for navigation to finish.
        let deadline = ContinuousClock.now + timeout
        var lastHTML = ""
        while ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(400))
            guard let html = await renderedHTML(of: webView), html != lastHTML else { continue }
            lastHTML = html
            // Parsing a large page takes a moment; keep it off the main actor.
            let draft = await Task.detached(priority: .userInitiated) {
                try? RecipeImporter.parse(html: html, sourceURL: sourceURL)
            }.value
            if let draft { return draft }
        }
        return nil
    }

    private static func renderedHTML(of webView: WKWebView) async -> String? {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("document.documentElement.outerHTML") { result, _ in
                continuation.resume(returning: result as? String)
            }
        }
    }
}
#endif
