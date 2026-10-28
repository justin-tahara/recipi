import Foundation

/// Best-effort import for pages without a JSON-LD Recipe. It reads
/// schema.org microdata (`itemprop="recipeIngredient"`) and the markup of
/// the common WordPress recipe plugins, then falls back to the page title.
///
/// This is deliberately heuristic. Add a pattern here, with a test fixture,
/// whenever a real site fails to import.
public enum FallbackRecipeParser {
    public static func parse(html: String, sourceURL: URL? = nil) -> RecipeDraft? {
        let ingredients = firstNonEmpty([
            elements(withAttribute: "itemprop", value: "recipeIngredient", in: html),
            elements(withAttribute: "itemprop", value: "ingredients", in: html),
            elements(withClass: "wprm-recipe-ingredient", in: html),
            elements(withClass: "tasty-recipes-ingredients", in: html, splitListItems: true),
        ])
        let steps = firstNonEmpty([
            elements(withAttribute: "itemprop", value: "recipeInstructions", in: html, splitListItems: true),
            elements(withClass: "wprm-recipe-instruction-text", in: html),
            elements(withClass: "tasty-recipes-instructions", in: html, splitListItems: true),
        ])
        guard !ingredients.isEmpty else { return nil }

        var draft = RecipeDraft(title: title(in: html) ?? sourceURL?.host() ?? "Untitled recipe")
        draft.sourceURL = sourceURL
        draft.ingredients = ingredients.map { RecipeDraft.Line($0) }
        draft.steps = steps.map { RecipeDraft.Line($0) }
        if let image = meta(property: "og:image", in: html) {
            draft.imageURL = URL(string: image, relativeTo: sourceURL)?.absoluteURL
        }
        draft.summary = meta(property: "og:description", in: html) ?? ""
        return draft
    }

    private static func firstNonEmpty(_ candidates: [[String]]) -> [String] {
        candidates.first { !$0.isEmpty } ?? []
    }

    private static func elements(withAttribute name: String, value: String, in html: String, splitListItems: Bool = false) -> [String] {
        let pattern = #"<(\w+)[^>]*\b"# + name + #"\s*=\s*["']"# + NSRegularExpression.escapedPattern(for: value) + #"["'][^>]*>(.*?)</\1>"#
        return texts(matching: pattern, captureGroup: 2, in: html, splitListItems: splitListItems)
    }

    private static func elements(withClass className: String, in html: String, splitListItems: Bool = false) -> [String] {
        // Match the class as a whole token, so "wprm-recipe-ingredient" doesn't
        // also match its "wprm-recipe-ingredient-amount" children.
        let pattern = #"<(\w+)[^>]*\bclass\s*=\s*["'](?:[^"']*\s)?"# + NSRegularExpression.escapedPattern(for: className) + #"(?:\s[^"']*)?["'][^>]*>(.*?)</\1>"#
        return texts(matching: pattern, captureGroup: 2, in: html, splitListItems: splitListItems)
    }

    private static func texts(matching pattern: String, captureGroup: Int, in html: String, splitListItems: Bool) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).flatMap { match -> [String] in
            guard let captured = Range(match.range(at: captureGroup), in: html) else { return [] }
            let fragment = String(html[captured])
            if splitListItems {
                let items = HTMLText.captures(of: #"<li[^>]*>(.*?)</li>"#, in: fragment).map(HTMLText.plainText)
                if !items.isEmpty { return items.filter { !$0.isEmpty } }
            }
            let text = HTMLText.plainText(fragment)
            return text.isEmpty ? [] : [text]
        }
    }

    private static func title(in html: String) -> String? {
        meta(property: "og:title", in: html)
            ?? HTMLText.captures(of: #"<title[^>]*>(.*?)</title>"#, in: html).first.map(HTMLText.plainText)
    }

    private static func meta(property: String, in html: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: property)
        let patterns = [
            #"<meta[^>]*(?:property|name)\s*=\s*["']"# + escaped + #"["'][^>]*content\s*=\s*["']([^"']*)["']"#,
            #"<meta[^>]*content\s*=\s*["']([^"']*)["'][^>]*(?:property|name)\s*=\s*["']"# + escaped + #"["']"#,
        ]
        for pattern in patterns {
            if let value = HTMLText.captures(of: pattern, in: html).first.map(HTMLText.decodeEntities), !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
