import Foundation

/// Reads a schema.org `Recipe` from the JSON-LD blocks in a page. Most
/// recipe sites publish one for Google's rich results, so this covers the
/// large majority of imports.
public enum SchemaRecipeParser {
    public static func parse(html: String, sourceURL: URL? = nil) -> RecipeDraft? {
        for object in jsonLDObjects(in: html) {
            let nodes = NodeIndex(object)
            guard let node = findRecipe(in: object),
                  let recipe = draft(from: node, sourceURL: sourceURL, nodes: nodes) else {
                continue
            }
            return recipe
        }
        return nil
    }

    /// Every JSON-LD block in the page that parses. A block that doesn't
    /// (a stray trailing comma, a CMS comment) is skipped, not fatal.
    static func jsonLDObjects(in html: String) -> [Any] {
        let blocks = HTMLText.captures(
            of: #"<script[^>]*\btype\s*=\s*["']?application/ld\+json[^>]*>(.*?)</script>"#,
            in: html
        )
        return blocks.compactMap { block in
            // Some sites emit raw newlines and tabs inside JSON strings, which
            // is invalid JSON. Outside strings they are only whitespace, so
            // flattening them is safe either way.
            var json = block
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
                .trimmingCharacters(in: .whitespaces)
            // Older themes wrap the block in CDATA or HTML comment markers.
            for wrapper in ["//<![CDATA[", "<![CDATA[", "//]]>", "]]>", "<!--", "-->"] {
                json = json.replacingOccurrences(of: wrapper, with: "")
            }
            json = json.trimmingCharacters(in: .whitespaces)
            if json.hasSuffix(";") { json.removeLast() }
            guard let data = json.data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        }
    }

    // MARK: - Finding the Recipe node

    static func findRecipe(in json: Any) -> [String: Any]? {
        if let array = json as? [Any] {
            for element in array {
                if let found = findRecipe(in: element) { return found }
            }
            return nil
        }
        guard let object = json as? [String: Any] else { return nil }
        if isRecipe(object["@type"]) { return object }
        for key in ["@graph", "mainEntity", "mainEntityOfPage", "itemListElement", "item"] {
            if let nested = object[key], let found = findRecipe(in: nested) { return found }
        }
        return nil
    }

    private static func isRecipe(_ type: Any?) -> Bool {
        let types: [String]
        if let single = type as? String {
            types = [single]
        } else if let many = type as? [Any] {
            types = many.compactMap { $0 as? String }
        } else {
            return false
        }
        // Handles "Recipe", "schema:Recipe" and "https://schema.org/Recipe".
        return types.contains { $0.split(whereSeparator: { $0 == "/" || $0 == ":" }).last?.lowercased() == "recipe" }
    }

    /// The nodes of a JSON-LD document by `@id`. Yoast and similar plugins
    /// put the recipe's image and author elsewhere in the `@graph` and only
    /// reference them, e.g. `"image": {"@id": "…#primaryimage"}`.
    struct NodeIndex {
        private var nodes: [String: [String: Any]] = [:]

        init(_ json: Any) {
            collect(json)
        }

        private mutating func collect(_ json: Any) {
            if let array = json as? [Any] {
                for element in array { collect(element) }
            } else if let object = json as? [String: Any] {
                // A bare reference has only "@id"; don't let it shadow the node.
                if let id = object["@id"] as? String, object.count > 1, nodes[id] == nil {
                    nodes[id] = object
                }
                for value in object.values { collect(value) }
            }
        }

        /// `value` with a bare `{"@id": …}` reference replaced by its node.
        func resolve(_ value: Any?) -> Any? {
            if let array = value as? [Any] { return array.map { resolve($0) ?? $0 } }
            guard let object = value as? [String: Any],
                  let id = object["@id"] as? String,
                  object.count == 1 || (object.count == 2 && object["@type"] != nil),
                  let node = nodes[id] else {
                return value
            }
            return node
        }
    }

    // MARK: - Mapping

    static func draft(from node: [String: Any], sourceURL: URL?, nodes: NodeIndex? = nil) -> RecipeDraft? {
        let index = nodes ?? NodeIndex(node)
        guard let title = text(node["name"]) ?? text(node["headline"]) else { return nil }

        var draft = RecipeDraft(title: title)
        draft.sourceURL = sourceURL ?? text(node["url"]).flatMap(URL.init(string:))
        draft.summary = text(node["description"]) ?? ""
        draft.author = name(of: index.resolve(node["author"]))
        draft.imageURL = imageURL(index.resolve(node["image"]), relativeTo: sourceURL)

        draft.prepTime = text(node["prepTime"]).flatMap(RecipeValues.duration(from:))
        draft.cookTime = text(node["cookTime"]).flatMap(RecipeValues.duration(from:))
        draft.totalTime = text(node["totalTime"]).flatMap(RecipeValues.duration(from:))

        let yields = yieldValues(node["recipeYield"] ?? node["yield"])
        draft.yieldText = RecipeValues.yieldText(from: yields)
        draft.servings = yields.lazy.compactMap(RecipeValues.servings(in:)).first

        draft.ingredients = strings(node["recipeIngredient"] ?? node["ingredients"]).map { RecipeDraft.Line($0) }
        draft.steps = steps(node["recipeInstructions"])
        draft.tags = tags(from: node)

        guard !draft.ingredients.isEmpty || !draft.steps.isEmpty else { return nil }
        return draft
    }

    /// A single-line value: a string, a number, the first of an array, or an
    /// object's `@value`, `text` or `name`.
    private static func text(_ value: Any?) -> String? {
        let raw: String?
        switch value {
        case let string as String: raw = string
        case let number as NSNumber: raw = number.stringValue
        case let array as [Any]: return array.lazy.compactMap { text($0) }.first
        case let object as [String: Any]: return text(object["@value"] ?? object["text"] ?? object["name"])
        default: raw = nil
        }
        guard let raw else { return nil }
        let cleaned = HTMLText.singleLine(raw)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func strings(_ value: Any?) -> [String] {
        if let array = value as? [Any] {
            return array.compactMap { text($0) }
        }
        if let single = value as? String {
            return HTMLText.plainText(single).components(separatedBy: .newlines).cleanedLines()
        }
        if let single = text(value) {
            return [single]
        }
        return []
    }

    private static func name(of value: Any?) -> String? {
        if let array = value as? [Any] {
            let names = array.compactMap { name(of: $0) }
            return names.isEmpty ? nil : names.joined(separator: ", ")
        }
        if let object = value as? [String: Any] { return text(object["name"]) }
        return text(value)
    }

    private static func imageURL(_ value: Any?, relativeTo base: URL?) -> URL? {
        let string: String?
        switch value {
        case let single as String: string = single
        case let array as [Any]: return array.lazy.compactMap { imageURL($0, relativeTo: base) }.first
        case let object as [String: Any]: string = object["url"] as? String ?? object["contentUrl"] as? String
        default: string = nil
        }
        guard let string = string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else { return nil }
        return URL(string: string, relativeTo: base)?.absoluteURL
    }

    private static func yieldValues(_ value: Any?) -> [String] {
        if let array = value as? [Any] { return array.compactMap { text($0) } }
        return text(value).map { [$0] } ?? []
    }

    private static func steps(_ value: Any?, section: String? = nil) -> [RecipeDraft.Line] {
        switch value {
        case let string as String:
            // A plain string, sometimes HTML (`<ol><li>…`), one step per line.
            return HTMLText.plainText(string)
                .components(separatedBy: .newlines)
                .cleanedLines()
                .map { RecipeDraft.Line($0, section: section) }
        case let array as [Any]:
            return array.flatMap { steps($0, section: section) }
        case let object as [String: Any]:
            if isType(object["@type"], "HowToSection") {
                let title = text(object["name"])
                return steps(object["itemListElement"], section: title ?? section)
            }
            if let nested = object["itemListElement"] {
                return steps(nested, section: section)
            }
            if let line = text(object["text"]) ?? text(object["name"]) {
                return [RecipeDraft.Line(line, section: section)]
            }
            return []
        default:
            return []
        }
    }

    private static func isType(_ type: Any?, _ expected: String) -> Bool {
        if let single = type as? String { return single.hasSuffix(expected) }
        if let many = type as? [Any] { return many.contains { ($0 as? String)?.hasSuffix(expected) == true } }
        return false
    }

    private static func tags(from node: [String: Any]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for key in ["recipeCategory", "recipeCuisine", "keywords"] {
            for value in strings(node[key]) {
                for tag in value.split(separator: ",") {
                    let trimmed = tag.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
                    result.append(trimmed)
                }
            }
        }
        return result
    }
}
