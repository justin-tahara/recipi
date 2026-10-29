import Foundation

/// Small helpers for turning bits of HTML into plain text and for finding
/// elements in a page. This is not an HTML parser; it only needs to cope with
/// what recipe sites put inside JSON-LD strings and recipe-card markup.
enum HTMLText {
    /// Plain text with one line per block: paragraphs, list items, headings
    /// and line breaks each end a line. Empty lines are dropped.
    static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "(?s)<!--.*?-->", with: "", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"(?i)<br\s*/?>|</(?:p|li|div|h[1-6]|tr|ol|ul|section)\s*>"#,
            with: "\n",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeEntities(text)
        return text
            .components(separatedBy: .newlines)
            .map { line in
                line.replacingOccurrences(of: "[ \\t\u{00A0}\u{2009}\u{202F}]+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Plain text on one line, for titles, ingredients and single steps.
    static func singleLine(_ html: String) -> String {
        plainText(html).replacingOccurrences(of: "\n", with: " ")
    }

    // MARK: - Entities

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "frac12": "½", "frac14": "¼", "frac34": "¾", "frac13": "⅓", "frac23": "⅔", "frac18": "⅛",
        "deg": "°", "ndash": "–", "mdash": "—", "minus": "−", "times": "×", "hellip": "…", "bull": "•", "middot": "·",
        "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“", "sbquo": "‚", "bdquo": "„", "laquo": "«", "raquo": "»",
        "prime": "′", "Prime": "″", "reg": "®", "copy": "©", "trade": "™", "thinsp": " ", "ensp": " ", "emsp": " ",
        "auml": "ä", "ouml": "ö", "uuml": "ü", "Auml": "Ä", "Ouml": "Ö", "Uuml": "Ü", "szlig": "ß",
        "aacute": "á", "agrave": "à", "acirc": "â", "eacute": "é", "egrave": "è", "ecirc": "ê", "euml": "ë",
        "Eacute": "É", "Egrave": "È", "iacute": "í", "igrave": "ì", "icirc": "î", "iuml": "ï",
        "oacute": "ó", "ograve": "ò", "ocirc": "ô", "uacute": "ú", "ugrave": "ù", "ucirc": "û",
        "ccedil": "ç", "Ccedil": "Ç", "ntilde": "ñ", "oelig": "œ", "OElig": "Œ", "aelig": "æ",
    ]

    /// Decodes named and numeric entities. Text that was escaped twice
    /// (`&amp;#8217;`, common in WordPress JSON-LD) is decoded twice.
    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        let once = decodeOnce(string)
        if string.range(of: "&amp;#?[A-Za-z0-9]+;", options: .regularExpression) != nil {
            return decodeOnce(once)
        }
        return once
    }

    private static func decodeOnce(_ string: String) -> String {
        var result = ""
        var index = string.startIndex
        while index < string.endIndex {
            let character = string[index]
            guard character == "&",
                  let semicolon = string[index...].prefix(12).firstIndex(of: ";") else {
                result.append(character)
                index = string.index(after: index)
                continue
            }
            let entity = String(string[string.index(after: index)..<semicolon])
            if let replacement = decode(entity: entity) {
                result += replacement
                index = string.index(after: semicolon)
            } else {
                result.append(character)
                index = string.index(after: index)
            }
        }
        return result
    }

    private static func decode(entity: String) -> String? {
        if let value = namedEntities[entity] ?? namedEntities[entity.lowercased()] { return value }
        guard entity.hasPrefix("#") else { return nil }
        let digits = entity.dropFirst()
        let scalarValue: UInt32?
        if digits.first == "x" || digits.first == "X" {
            scalarValue = UInt32(digits.dropFirst(), radix: 16)
        } else {
            scalarValue = UInt32(digits, radix: 10)
        }
        guard let scalarValue, let scalar = Unicode.Scalar(scalarValue) else { return nil }
        return String(Character(scalar))
    }

    // MARK: - Finding things

    /// Returns the first capture group of every match of `pattern`.
    static func captures(of pattern: String, in html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let captureRange = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[captureRange])
        }
    }

    /// An element found by `elements(matching:in:)`.
    struct Element {
        /// The opening tag, e.g. `<li class="wprm-recipe-ingredient">`.
        var openingTag: String
        /// The tag name, lowercased.
        var name: String
        /// Everything between the opening tag and its matching closing tag.
        var inner: String
        /// The opening-tag pattern's capture groups after the tag name.
        var captures: [String]
        /// The whole element, opening to closing tag, in the searched string.
        var range: NSRange
    }

    private static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr",
    ]

    /// Finds the elements whose opening tag matches `openingTagPattern` and
    /// returns each with its full contents, counting nested tags of the same
    /// name so a `<div>` inside a `<div>` doesn't end the match early. The
    /// pattern's first capture group must be the tag name. An element inside
    /// an earlier match is skipped.
    static func elements(matching openingTagPattern: String, in html: String) -> [Element] {
        guard let regex = try? NSRegularExpression(pattern: openingTagPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let source = html as NSString
        var results: [Element] = []
        var consumedUpTo = 0
        for match in regex.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            guard match.range.location >= consumedUpTo,
                  match.numberOfRanges > 1,
                  match.range(at: 1).location != NSNotFound else { continue }
            let name = source.substring(with: match.range(at: 1)).lowercased()
            let openingTag = source.substring(with: match.range)
            let captures = (2..<max(2, match.numberOfRanges)).map { group in
                let range = match.range(at: group)
                return range.location == NSNotFound ? "" : source.substring(with: range)
            }

            let contentStart = NSMaxRange(match.range)
            var contentEnd = contentStart
            var elementEnd = contentStart
            if !voidElements.contains(name), !openingTag.hasSuffix("/>") {
                if let closing = closingTag(of: name, in: source, from: contentStart) {
                    contentEnd = closing.location
                    elementEnd = NSMaxRange(closing)
                } else {
                    // Unclosed, like an `<li>` relying on the next one to end
                    // it: stop at the next tag of the same name.
                    let next = nextOpeningTag(of: name, in: source, from: contentStart)
                    contentEnd = next ?? source.length
                    elementEnd = contentEnd
                }
            }
            let inner = source.substring(with: NSRange(location: contentStart, length: contentEnd - contentStart))
            let range = NSRange(location: match.range.location, length: elementEnd - match.range.location)
            results.append(Element(openingTag: openingTag, name: name, inner: inner, captures: captures, range: range))
            consumedUpTo = elementEnd
        }
        return results
    }

    private static func closingTag(of name: String, in source: NSString, from start: Int) -> NSRange? {
        let pattern = "<(/?)" + NSRegularExpression.escapedPattern(for: name) + #"\b[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        var depth = 1
        var found: NSRange?
        regex.enumerateMatches(in: source as String, range: NSRange(location: start, length: source.length - start)) { match, _, stop in
            guard let match else { return }
            if match.range(at: 1).length > 0 {
                depth -= 1
                if depth == 0 {
                    found = match.range
                    stop.pointee = true
                }
            } else if !source.substring(with: match.range).hasSuffix("/>") {
                depth += 1
            }
        }
        return found
    }

    private static func nextOpeningTag(of name: String, in source: NSString, from start: Int) -> Int? {
        let pattern = "<" + NSRegularExpression.escapedPattern(for: name) + #"\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: source as String, range: NSRange(location: start, length: source.length - start)) else {
            return nil
        }
        return match.range.location
    }

    /// `html` without the elements whose opening tag matches the pattern.
    static func removingElements(matching openingTagPattern: String, from html: String) -> String {
        let found = elements(matching: openingTagPattern, in: html)
        guard !found.isEmpty else { return html }
        let result = NSMutableString(string: html)
        for element in found.reversed() {
            result.replaceCharacters(in: element.range, with: "")
        }
        return result as String
    }

    /// `html` without scripts, styles and comments, so recipe markup quoted
    /// inside them isn't read twice.
    static func removingScriptsAndComments(_ html: String) -> String {
        html.replacingOccurrences(of: "(?s)<!--.*?-->", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<script\b[^>]*>.*?</script\s*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<style\b[^>]*>.*?</style\s*>"#, with: "", options: .regularExpression)
    }

    /// An opening-tag pattern for elements carrying one of `tokens` as a whole
    /// token of `attribute` (e.g. `class` or `itemprop`). Capture group 1 is the
    /// tag name, group 2 the token that matched.
    static func openingTagPattern(attribute: String = "class", tokens: [String]) -> String {
        let alternatives = tokens.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        return #"<(\w+)\b[^>]*?(?<![\w-])"# + NSRegularExpression.escapedPattern(for: attribute)
            + #"\s*=\s*["'](?:[^"']*\s)?("# + alternatives + #")(?:\s[^"']*)?["'][^>]*>"#
    }

    // MARK: - Attributes, meta and link tags

    /// The value of `name` in an opening tag, entities decoded.
    static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = #"(?<![\w-])"# + NSRegularExpression.escapedPattern(for: name)
            + #"\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)) else {
            return nil
        }
        for group in 1...3 {
            if let range = Range(match.range(at: group), in: tag) {
                return decodeEntities(String(tag[range]))
            }
        }
        return nil
    }

    /// The content of the first `<meta>` whose `property`, `name` or
    /// `itemprop` is `key`, e.g. `og:image`.
    static func metaContent(_ key: String, in html: String) -> String? {
        let key = key.lowercased()
        for tag in captures(of: #"(<meta\b[^>]*>)"#, in: html) {
            let keys = ["property", "name", "itemprop"].compactMap { attribute($0, in: tag)?.lowercased() }
            guard keys.contains(key),
                  let content = attribute("content", in: tag)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else { continue }
            return content
        }
        return nil
    }

    /// The `href` of the first `<link>` with `rel` among its tokens.
    static func linkHref(rel: String, in html: String) -> String? {
        let rel = rel.lowercased()
        for tag in captures(of: #"(<link\b[^>]*>)"#, in: html) {
            guard let rels = attribute("rel", in: tag)?.lowercased().split(separator: " "),
                  rels.contains(Substring(rel)),
                  let href = attribute("href", in: tag)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !href.isEmpty else { continue }
            return href
        }
        return nil
    }

    /// The target of a `<meta http-equiv="refresh" content="0; url=…">`.
    static func metaRefreshTarget(in html: String) -> String? {
        for tag in captures(of: #"(<meta\b[^>]*>)"#, in: html) {
            guard attribute("http-equiv", in: tag)?.lowercased() == "refresh",
                  let content = attribute("content", in: tag),
                  let target = captures(of: #"url\s*=\s*['"]?([^'"]+)"#, in: content).first else { continue }
            let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
