import Foundation

/// Finds the link to import in text that was shared or pasted, and tidies
/// it: apps often share a page as text, with its title or a comment around
/// the link, and wrap it in a redirect or an AMP viewer.
public enum SharedLink {
    /// The first http(s) link in `text`, if there is one. A link written
    /// with `http://` or `https://` wins over a bare domain mentioned
    /// earlier ("From example.com: https://example.com/pie").
    public static func firstWebURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only take the whole text as the link when it has no spaces, since
        // `URL(string:)` would otherwise escape the rest into the path.
        if !trimmed.contains(where: \.isWhitespace), let url = URL(string: trimmed), isWeb(url), url.host() != nil {
            return url
        }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        var bareDomain: URL?
        for match in detector.matches(in: trimmed, range: range) {
            guard let url = match.url, isWeb(url) else { continue }
            let written = Range(match.range, in: trimmed).map { trimmed[$0].lowercased() } ?? ""
            if written.hasPrefix("http://") || written.hasPrefix("https://") {
                return url
            }
            if bareDomain == nil { bareDomain = url }
        }
        return bareDomain
    }

    /// The page to fetch for a shared link: the real page behind a Google
    /// AMP viewer, an AMP cache, or a Google or Facebook redirect link.
    /// Anything else comes back as it is.
    public static func pageURL(for url: URL) -> URL {
        var current = url
        // A wrapper can wrap another one; a few rounds is plenty.
        for _ in 0..<3 {
            guard let inner = unwrapped(current), inner != current else { break }
            current = inner
        }
        return current
    }

    /// `url` without the query parameters that only track where a click
    /// came from (`utm_*`, `fbclid`, `gclid` and the like). Every other
    /// parameter, and the fragment, stays, since a page may need it.
    public static func removingTracking(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.percentEncodedQueryItems, !items.isEmpty else { return url }
        let kept = items.filter { !isTrackingParameter($0.name) }
        guard kept.count != items.count else { return url }
        components.percentEncodedQueryItems = kept.isEmpty ? nil : kept
        return components.url ?? url
    }

    /// A key under which two links to the same page match: no scheme,
    /// `www.` or tracking parameters, the host lowercased, no trailing slash
    /// and no fragment (a "Jump to recipe" link adds one).
    public static func sourceKey(for url: URL) -> String {
        let url = removingTracking(from: url)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              var host = components.host?.lowercased() else {
            return url.absoluteString
        }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        var path = components.percentEncodedPath
        while path.hasSuffix("/") { path.removeLast() }
        var key = host + path
        if let query = components.percentEncodedQuery, !query.isEmpty { key += "?" + query }
        return key
    }

    // MARK: - Details

    private static let trackingParameters: Set<String> = [
        "fbclid", "gclid", "dclid", "gbraid", "wbraid", "msclkid", "yclid", "twclid", "ttclid",
        "igshid", "igsh", "mc_cid", "mc_eid", "_hsenc", "_hsmi", "mkt_tok",
    ]

    static func isTrackingParameter(_ name: String) -> Bool {
        let name = name.lowercased()
        return name.hasPrefix("utm_") || trackingParameters.contains(name)
    }

    private static func isWeb(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// The page one wrapper stands for, or nil when `url` isn't a wrapper.
    private static func unwrapped(_ url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased() else { return nil }
        let path = components.percentEncodedPath

        if isGoogle(host) {
            // google.com/amp/s/example.com/pie/amp/ is Google's AMP viewer
            // for https://example.com/pie/amp/ (without the `s/`, http).
            if path.hasPrefix("/amp/") {
                return embeddedURL(afterPrefix: "/amp/", in: components)
            }
            // google.com/url?q=… and ?url=… are redirect links.
            if path == "/url" {
                return queryURL(named: ["q", "url"], in: components)
            }
        }
        // example-com.cdn.ampproject.org/c/s/example.com/pie is the AMP
        // cache's copy (`/c/` content, `/v/` viewer).
        if host.hasSuffix(".cdn.ampproject.org") {
            for prefix in ["/c/", "/v/"] where path.hasPrefix(prefix) {
                return embeddedURL(afterPrefix: prefix, in: components)
            }
        }
        // l.facebook.com/l.php?u=… is Facebook's link redirect.
        if host == "l.facebook.com" || host == "lm.facebook.com", path == "/l.php" {
            return queryURL(named: ["u"], in: components)
        }
        return nil
    }

    private static func isGoogle(_ host: String) -> Bool {
        let host = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        // google.com, google.de, google.co.uk, …
        return host.hasPrefix("google.") && host.split(separator: ".").count <= 3
    }

    /// The address written into the path after `prefix`: `s/host/path`
    /// for https, `host/path` for http. The wrapper's query and fragment
    /// belong to the page, so they're kept.
    private static func embeddedURL(afterPrefix prefix: String, in components: URLComponents) -> URL? {
        var rest = String(components.percentEncodedPath.dropFirst(prefix.count))
        var scheme = "http"
        if rest.hasPrefix("s/") {
            scheme = "https"
            rest.removeFirst(2)
        }
        guard let host = rest.split(separator: "/", maxSplits: 1).first, host.contains(".") else { return nil }
        var address = "\(scheme)://\(rest)"
        if let query = components.percentEncodedQuery, !query.isEmpty { address += "?\(query)" }
        if let fragment = components.percentEncodedFragment, !fragment.isEmpty { address += "#\(fragment)" }
        guard let url = URL(string: address), url.host() != nil else { return nil }
        return url
    }

    private static func queryURL(named names: [String], in components: URLComponents) -> URL? {
        for name in names {
            guard let value = components.queryItems?.first(where: { $0.name == name })?.value,
                  let url = URL(string: value), isWeb(url), url.host() != nil else { continue }
            return url
        }
        return nil
    }
}
