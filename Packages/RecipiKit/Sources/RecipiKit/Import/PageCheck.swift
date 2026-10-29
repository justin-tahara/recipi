import Foundation

/// Tells why a fetched page can't be imported when the reason is the site
/// rather than its markup: a file instead of a page, an error status, or a
/// bot check standing in for the page. The importer asks only after the
/// parsers found no recipe, so a page that has one is never turned away.
enum PageCheck {
    struct Verdict: Equatable, Sendable {
        var error: RecipeImportError
        /// What gave it away, for the nightly live check's report.
        var reason: String
    }

    // MARK: - Files instead of pages

    private static let fileTypePrefixes = ["image/", "audio/", "video/", "font/", "model/"]
    private static let fileTypes: Set<String> = [
        "application/pdf", "application/zip", "application/gzip", "application/x-zip-compressed",
        "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/epub+zip",
    ]

    /// A verdict when a successful response is a file (a PDF, a photo, a
    /// video) rather than a web page, told from its content type or, when
    /// the server didn't say, its first bytes.
    static func fileInsteadOfPage(mimeType: String?, data: Data) -> Verdict? {
        let mime = mimeType?.lowercased() ?? ""
        if fileTypePrefixes.contains(where: { mime.hasPrefix($0) }) || fileTypes.contains(mime) {
            return Verdict(error: .notAWebPage, reason: "content type \(mime)")
        }
        if let kind = fileKind(of: data) {
            return Verdict(error: .notAWebPage, reason: "\(kind) file")
        }
        return nil
    }

    private static let signatures: [(kind: String, bytes: [UInt8])] = [
        ("PDF", Array("%PDF-".utf8)),
        ("PNG", [0x89, 0x50, 0x4E, 0x47]),
        ("JPEG", [0xFF, 0xD8, 0xFF]),
        ("GIF", Array("GIF8".utf8)),
        ("zip", [0x50, 0x4B, 0x03, 0x04]),
    ]

    private static func fileKind(of data: Data) -> String? {
        let head = Array(data.prefix(8))
        return signatures.first { head.starts(with: $0.bytes) }?.kind
    }

    // MARK: - Pages the site wouldn't show

    /// Why a page with no recipe on it failed, when it was the site: a
    /// missing page, an error status, or a bot check. Nil when it's an
    /// ordinary page that has no recipe.
    static func problem(status: Int?, html: String) -> Verdict? {
        let challenge = challengeMarker(in: html)
        if let status, status >= 400 {
            let reason = "HTTP \(status)" + (challenge.map { ", \($0)" } ?? "")
            switch status {
            case 404, 410:
                return Verdict(error: .pageNotFound, reason: reason)
            case 400..<500:
                // 403 and 429 are the usual answers to a client a site
                // doesn't trust; the rest of 4xx are rare for a page link.
                return Verdict(error: .blockedBySite, reason: reason)
            default:
                // A bot check often comes back as a 503.
                return Verdict(error: challenge == nil ? .siteUnavailable : .blockedBySite, reason: reason)
            }
        }
        if let challenge {
            return Verdict(error: .blockedBySite, reason: challenge)
        }
        if html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Verdict(error: .blockedBySite, reason: "empty page")
        }
        return nil
    }

    /// Text that only appears on a bot check or block page, with the
    /// service it belongs to. Matched anywhere in the page.
    private static let challengeMarkers: [(text: String, name: String)] = [
        ("_cf_chl_opt", "Cloudflare challenge"),
        ("cf-chl-", "Cloudflare challenge"),
        ("<title>just a moment", "Cloudflare challenge"),
        ("attention required! | cloudflare", "Cloudflare block"),
        ("sorry, you have been blocked", "Cloudflare block"),
        ("captcha-delivery.com", "DataDome challenge"),
        ("px-captcha", "PerimeterX challenge"),
        ("incapsula incident", "Imperva block"),
        ("sucuri website firewall", "Sucuri block"),
        ("/_sec/cp_challenge", "Akamai challenge"),
        ("vercel security checkpoint", "Vercel challenge"),
    ]

    /// Text that also turns up on ordinary pages (a comment form's captcha,
    /// a bot-detection script), so it only counts on a page with little
    /// else to read.
    private static let weakChallengeMarkers: [(text: String, name: String)] = [
        ("captcha", "captcha"),
        ("access denied", "access denied"),
        ("verify you are human", "human check"),
        ("verify you are a human", "human check"),
        ("are you a robot", "robot check"),
        ("unusual traffic", "unusual-traffic block"),
        ("request blocked", "request blocked"),
        ("ddos-guard", "DDoS-Guard"),
        ("awswaf", "AWS WAF challenge"),
        ("_incapsula_resource", "Imperva challenge"),
        ("enable javascript and cookies", "JavaScript check"),
    ]

    /// Block pages are short; a real article with a captcha on its comment
    /// form is not.
    private static let shortPageTextLength = 1_500

    /// The bot check or block page `html` is, if it looks like one.
    static func challengeMarker(in html: String) -> String? {
        let lowered = html.lowercased()
        if let strong = challengeMarkers.first(where: { lowered.contains($0.text) }) {
            return strong.name
        }
        guard let weak = weakChallengeMarkers.first(where: { lowered.contains($0.text) }) else { return nil }
        let text = HTMLText.plainText(HTMLText.removingScriptsAndComments(html))
        return text.count < shortPageTextLength ? weak.name : nil
    }
}
