import Foundation

/// Small helpers for turning bits of HTML into plain text. This is not an
/// HTML parser; it only needs to cope with what recipe sites put inside
/// JSON-LD strings and simple elements.
enum HTMLText {
    static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeEntities(text)
        text = text.replacingOccurrences(of: "[ \\t\u{00A0}]+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        let named: [String: String] = [
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
            "frac12": "½", "frac14": "¼", "frac34": "¾", "deg": "°", "ndash": "–", "mdash": "—",
            "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“", "hellip": "…", "eacute": "é",
        ]

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
            if let replacement = decode(entity: entity, named: named) {
                result += replacement
                index = string.index(after: semicolon)
            } else {
                result.append(character)
                index = string.index(after: index)
            }
        }
        return result
    }

    private static func decode(entity: String, named: [String: String]) -> String? {
        if let value = named[entity.lowercased()] { return value }
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
}
