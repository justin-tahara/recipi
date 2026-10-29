import Foundation

/// A page someone shared from Safari, as Safari had it loaded: its address
/// and its HTML after the page's own scripts ran. The share extension's
/// preprocessing script (`RecipiShare/Resources/SafariPage.js`) collects it,
/// so recipi can read the recipe without downloading the page again, which
/// gets past sites that turn away apps but not browsers.
public struct SharedPage: Sendable, Equatable {
    public var url: URL
    public var html: String

    public init(url: URL, html: String) {
        self.url = url
        self.html = html
    }

    /// Reads the dictionary the preprocessing script hands back (the value
    /// of `NSExtensionJavaScriptPreprocessingResultsKey`). Nil unless it has
    /// a web address and some HTML.
    public init?(preprocessingResults results: [AnyHashable: Any]) {
        guard let address = results["url"] as? String,
              let url = URL(string: address),
              url.scheme == "https" || url.scheme == "http",
              let html = results["html"] as? String,
              !html.isEmpty else { return nil }
        self.init(url: url, html: html)
    }
}
