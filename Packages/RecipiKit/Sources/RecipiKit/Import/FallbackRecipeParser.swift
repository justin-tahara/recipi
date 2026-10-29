import Foundation

/// Best-effort import for pages without a JSON-LD Recipe. It reads
/// schema.org microdata (`itemprop="recipeIngredient"`) and the markup of
/// the common WordPress recipe plugins, then falls back to the page title.
///
/// This is deliberately heuristic. Add a pattern here, with a test fixture,
/// whenever a real site fails to import.
public enum FallbackRecipeParser {
    public static func parse(html: String, sourceURL: URL? = nil) -> RecipeDraft? {
        let page = HTMLText.removingScriptsAndComments(html)
        let scope = microdataScope(in: page)
        let area = scope ?? page
        let wprm = wordPressRecipeMaker(in: page)
        let tasty = tastyRecipes(in: page)

        let ingredients = firstNonEmpty([
            microdataLines(property: "recipeIngredient", in: area),
            microdataLines(property: "ingredients", in: area),
            wprm.ingredients,
            tasty.ingredients,
        ])
        let steps = firstNonEmpty([
            microdataSteps(in: area),
            wprm.steps,
            tasty.steps,
        ])
        guard !ingredients.isEmpty else { return nil }

        // Scalar values are read with nested items (the author, a rating)
        // taken out, so their `name` isn't mistaken for the recipe's.
        let scalars = scope.map(withoutNestedItems)

        var draft = RecipeDraft(title: title(in: page, scalars: scalars) ?? sourceURL?.host() ?? "Untitled recipe")
        draft.sourceURL = sourceURL
        draft.ingredients = ingredients
        draft.steps = steps
        draft.summary = scalars.flatMap { microdataValue("description", in: $0) }
            ?? HTMLText.metaContent("og:description", in: page)
            ?? ""

        let yield = scalars.flatMap { microdataValue("recipeYield", in: $0) }
            ?? firstText(classTokens: ["wprm-recipe-servings", "tasty-recipes-yield"], in: page)
        draft.yieldText = yield
        draft.servings = yield.flatMap(RecipeValues.servings(in:))

        if let scalars {
            draft.prepTime = microdataValue("prepTime", in: scalars).flatMap(RecipeValues.duration(from:))
            draft.cookTime = microdataValue("cookTime", in: scalars).flatMap(RecipeValues.duration(from:))
            draft.totalTime = microdataValue("totalTime", in: scalars).flatMap(RecipeValues.duration(from:))
        }

        let image = scalars.flatMap { microdataValue("image", in: $0) } ?? HTMLText.metaContent("og:image", in: page)
        draft.imageURL = image.flatMap { URL(string: $0, relativeTo: sourceURL)?.absoluteURL }
        return draft
    }

    private static func firstNonEmpty(_ candidates: [[RecipeDraft.Line]]) -> [RecipeDraft.Line] {
        candidates.first { !$0.isEmpty } ?? []
    }

    // MARK: - Microdata

    /// The contents of the element marked `itemtype="…schema.org/Recipe"`.
    private static func microdataScope(in html: String) -> String? {
        let pattern = #"<(\w+)\b[^>]*?(?<![\w-])itemtype\s*=\s*["'][^"']*schema\.org/Recipe["'][^>]*>"#
        return HTMLText.elements(matching: pattern, in: html).first?.inner
    }

    private static func withoutNestedItems(_ scope: String) -> String {
        HTMLText.removingElements(matching: #"<(\w+)\b[^>]*?(?<![\w-])itemscope\b[^>]*>"#, from: scope)
    }

    private static func microdataElements(_ property: String, in html: String) -> [HTMLText.Element] {
        HTMLText.elements(matching: HTMLText.openingTagPattern(attribute: "itemprop", tokens: [property]), in: html)
    }

    private static func microdataLines(property: String, in html: String) -> [RecipeDraft.Line] {
        microdataElements(property, in: html)
            .compactMap(itemValue)
            .map { RecipeDraft.Line($0) }
    }

    private static func microdataValue(_ property: String, in html: String) -> String? {
        microdataElements(property, in: html).lazy.compactMap(itemValue).first
    }

    /// A microdata value: a `content` or `datetime` attribute, an image's
    /// `src`, a link's `href`, or else the element's text.
    private static func itemValue(_ element: HTMLText.Element) -> String? {
        let value: String?
        if let content = HTMLText.attribute("content", in: element.openingTag) {
            value = content
        } else {
            switch element.name {
            case "time": value = HTMLText.attribute("datetime", in: element.openingTag) ?? lineText(element.inner)
            case "img", "source": value = HTMLText.attribute("src", in: element.openingTag) ?? HTMLText.attribute("data-src", in: element.openingTag)
            case "a", "link": value = HTMLText.attribute("href", in: element.openingTag)
            default: value = lineText(element.inner)
            }
        }
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Steps marked `itemprop="recipeInstructions"`: one per element when
    /// each step is its own `HowToStep`, otherwise the list items, paragraphs
    /// or lines inside a single container.
    private static func microdataSteps(in html: String) -> [RecipeDraft.Line] {
        microdataElements("recipeInstructions", in: html).flatMap { element -> [RecipeDraft.Line] in
            if let text = microdataValue("text", in: element.inner) {
                return [RecipeDraft.Line(text)]
            }
            return blockLines(in: element.inner).map { RecipeDraft.Line($0) }
        }
    }

    private static func blockLines(in html: String) -> [String] {
        for tag in ["li", "p"] {
            let items = HTMLText.elements(matching: "<(" + tag + #")\b[^>]*>"#, in: html).compactMap { lineText($0.inner) }
            if !items.isEmpty { return items }
        }
        return HTMLText.plainText(html).components(separatedBy: .newlines).cleanedLines()
    }

    // MARK: - Recipe plugins

    private enum Kind { case ingredient, step }

    private enum Token {
        case heading(String?)
        case item(Kind, String)
    }

    /// WP Recipe Maker. Group headings (`wprm-recipe-group-name`) sit before
    /// the ingredients or steps they head, so the page is read in order.
    private static func wordPressRecipeMaker(in html: String) -> (ingredients: [RecipeDraft.Line], steps: [RecipeDraft.Line]) {
        let pattern = HTMLText.openingTagPattern(tokens: ["wprm-recipe-group-name", "wprm-recipe-ingredient", "wprm-recipe-instruction-text"])
        let tokens = HTMLText.elements(matching: pattern, in: html).compactMap { element -> Token? in
            let text = lineText(element.inner)
            switch element.captures.first?.lowercased() ?? "" {
            case "wprm-recipe-group-name": return .heading(text)
            case "wprm-recipe-ingredient": return text.map { .item(.ingredient, $0) }
            default: return text.map { .item(.step, $0) }
            }
        }
        return sectioned(tokens)
    }

    /// Tasty Recipes. Each list lives in a container with an optional header
    /// (the "Ingredients" title and scale buttons) and `h4` group headings.
    private static func tastyRecipes(in html: String) -> (ingredients: [RecipeDraft.Line], steps: [RecipeDraft.Line]) {
        (
            sectioned(tastyTokens(container: "tasty-recipes-ingredients", kind: .ingredient, in: html)).ingredients,
            sectioned(tastyTokens(container: "tasty-recipes-instructions", kind: .step, in: html)).steps
        )
    }

    private static func tastyTokens(container: String, kind: Kind, in html: String) -> [Token] {
        guard let body = HTMLText.elements(matching: HTMLText.openingTagPattern(tokens: [container]), in: html).first?.inner else {
            return []
        }
        let content = HTMLText.removingElements(matching: HTMLText.openingTagPattern(tokens: [container + "-header"]), from: body)
        let elements = HTMLText.elements(matching: #"<(h[2-6]|li)\b[^>]*>"#, in: content)
        if elements.contains(where: { $0.name == "li" }) {
            return elements.compactMap { element in
                let text = lineText(element.inner)
                if element.name == "li" { return text.map { .item(kind, $0) } }
                return .heading(text)
            }
        }
        return blockLines(in: content).map { .item(kind, $0) }
    }

    /// Turns headings and items, in page order, into lines with sections. A
    /// heading applies to the items after it until the next heading, or until
    /// the list switches from ingredients to steps.
    private static func sectioned(_ tokens: [Token]) -> (ingredients: [RecipeDraft.Line], steps: [RecipeDraft.Line]) {
        var ingredients: [RecipeDraft.Line] = []
        var steps: [RecipeDraft.Line] = []
        var section: String?
        var lastKind: Kind?
        var headingSinceLastItem = false
        for token in tokens {
            switch token {
            case .heading(let text):
                section = text
                headingSinceLastItem = true
            case .item(let kind, let text):
                if kind != lastKind, !headingSinceLastItem { section = nil }
                let line = RecipeDraft.Line(text, section: section)
                switch kind {
                case .ingredient: ingredients.append(line)
                case .step: steps.append(line)
                }
                lastKind = kind
                headingSinceLastItem = false
            }
        }
        return (ingredients, steps)
    }

    // MARK: - Text

    /// Checkboxes and screen-reader labels inside recipe cards.
    private static let hiddenParts = HTMLText.openingTagPattern(tokens: [
        "wprm-checkbox-container", "tr-ingredient-checkbox-container",
        "sr-only", "screen-reader-text", "wprm-screen-reader-text",
    ])

    private static func lineText(_ html: String) -> String? {
        let visible = HTMLText.removingElements(matching: hiddenParts, from: html)
        let text = HTMLText.singleLine(visible)
            .trimmingCharacters(in: CharacterSet(charactersIn: "▢☐□").union(.whitespaces))
        return text.isEmpty ? nil : text
    }

    private static func firstText(classTokens: [String], in html: String) -> String? {
        HTMLText.elements(matching: HTMLText.openingTagPattern(tokens: classTokens), in: html).lazy.compactMap { lineText($0.inner) }.first
    }

    private static func title(in html: String, scalars: String?) -> String? {
        scalars.flatMap { microdataValue("name", in: $0) }
            ?? firstText(classTokens: ["wprm-recipe-name", "tasty-recipes-title"], in: html)
            ?? HTMLText.metaContent("og:title", in: html)
            ?? HTMLText.captures(of: #"<title[^>]*>(.*?)</title>"#, in: html).first.map(HTMLText.singleLine)
    }
}
