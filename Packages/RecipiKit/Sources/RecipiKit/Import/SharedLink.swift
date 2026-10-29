import Foundation

/// Finds the link to import in text that was shared or pasted. Apps often
/// share a page as text, with its title or a comment around the link.
public enum SharedLink {
    /// The first http(s) link in `text`, if there is one.
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
        return detector.matches(in: trimmed, range: range).lazy.compactMap(\.url).first(where: isWeb)
    }

    private static func isWeb(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
