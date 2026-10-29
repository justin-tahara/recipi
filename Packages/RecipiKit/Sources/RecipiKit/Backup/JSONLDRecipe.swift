import Foundation

// The JSON in each recipe file. The top level is a schema.org `Recipe`, so
// other apps (and recipi's own web importer) can read it. The
// `recipi:extension` object holds the exact values a restore needs:
// section headings, times in seconds, notes, favorite, tags and dates.

/// Written for each recipe in a backup.
struct JSONLDRecipe: Encodable {
    let context = "https://schema.org"
    let type = "Recipe"
    var identifier: String
    var name: String
    var description: String?
    var url: String?
    var author: Person?
    var image: String?
    var recipeYield: String?
    var prepTime: String?
    var cookTime: String?
    var totalTime: String?
    var recipeIngredient: [String]
    var recipeInstructions: [Instruction]
    var keywords: String?
    var dateCreated: String
    var dateModified: String
    var recipi: RecipiExtension

    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case type = "@type"
        case identifier, name, description, url, author, image, recipeYield
        case prepTime, cookTime, totalTime, recipeIngredient, recipeInstructions
        case keywords, dateCreated, dateModified
        case recipi = "recipi:extension"
    }

    struct Person: Encodable {
        let type = "Person"
        var name: String

        enum CodingKeys: String, CodingKey {
            case type = "@type"
            case name
        }
    }

    /// A `HowToStep`, or a `HowToSection` of steps under a heading.
    enum Instruction: Encodable {
        case step(String)
        case section(name: String, steps: [String])

        private enum CodingKeys: String, CodingKey {
            case type = "@type"
            case text, name, itemListElement
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .step(let text):
                try container.encode("HowToStep", forKey: .type)
                try container.encode(text, forKey: .text)
            case .section(let name, let steps):
                try container.encode("HowToSection", forKey: .type)
                try container.encode(name, forKey: .name)
                try container.encode(steps.map(Instruction.step), forKey: .itemListElement)
            }
        }
    }

    init(_ recipe: BackupRecipe, photoPath: String?) {
        identifier = recipe.id.uuidString.lowercased()
        name = recipe.title
        description = recipe.summary.isEmpty ? nil : recipe.summary
        url = recipe.sourceURL?.absoluteString
        author = recipe.author.flatMap { $0.isEmpty ? nil : Person(name: $0) }
        image = photoPath
        recipeYield = recipe.yieldText ?? recipe.servings.map { String($0) }
        prepTime = recipe.prepTime.flatMap(DurationText.iso8601)
        cookTime = recipe.cookTime.flatMap(DurationText.iso8601)
        totalTime = recipe.totalTime.flatMap(DurationText.iso8601)
        recipeIngredient = recipe.ingredients.map(\.text)
        recipeInstructions = Self.instructions(from: recipe.steps)
        keywords = recipe.tags.isEmpty ? nil : recipe.tags.joined(separator: ", ")
        dateCreated = Timestamp.string(from: recipe.createdAt)
        dateModified = Timestamp.string(from: recipe.updatedAt)
        recipi = RecipiExtension(recipe)
    }

    /// Consecutive steps under the same heading become one `HowToSection`.
    private static func instructions(from steps: [RecipeDraft.Line]) -> [Instruction] {
        var result: [Instruction] = []
        var index = steps.startIndex
        while index < steps.endIndex {
            guard let section = steps[index].section else {
                result.append(.step(steps[index].text))
                index += 1
                continue
            }
            var texts: [String] = []
            while index < steps.endIndex, steps[index].section == section {
                texts.append(steps[index].text)
                index += 1
            }
            result.append(.section(name: section, steps: texts))
        }
        return result
    }
}

/// recipi's own fields. Readers must ignore keys they don't know and treat
/// a missing list as empty, so later versions can add keys (a cook log, for
/// example) without changing the format version.
struct RecipiExtension: Codable {
    var id: String
    var servings: Int?
    var yieldText: String?
    var prepTime: Double?
    var cookTime: Double?
    var totalTime: Double?
    var notes: String
    var isFavorite: Bool
    var tags: [String]
    var ingredients: [Line]
    var steps: [Line]
    var createdAt: String?
    var updatedAt: String?

    struct Line: Codable {
        var text: String
        var section: String?

        enum CodingKeys: String, CodingKey {
            case text, section
        }

        init(_ line: RecipeDraft.Line) {
            text = line.text
            section = line.section
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
            section = try container.decodeIfPresent(String.self, forKey: .section)
        }

        var draftLine: RecipeDraft.Line { RecipeDraft.Line(text, section: section) }
    }

    enum CodingKeys: String, CodingKey {
        case id, servings, yieldText, prepTime, cookTime, totalTime
        case notes, isFavorite, tags, ingredients, steps, createdAt, updatedAt
    }

    init(_ recipe: BackupRecipe) {
        id = recipe.id.uuidString.lowercased()
        servings = recipe.servings
        yieldText = recipe.yieldText
        prepTime = recipe.prepTime
        cookTime = recipe.cookTime
        totalTime = recipe.totalTime
        notes = recipe.notes
        isFavorite = recipe.isFavorite
        tags = recipe.tags
        ingredients = recipe.ingredients.map { Line($0) }
        steps = recipe.steps.map { Line($0) }
        createdAt = Timestamp.string(from: recipe.createdAt)
        updatedAt = Timestamp.string(from: recipe.updatedAt)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        servings = try container.decodeIfPresent(Int.self, forKey: .servings)
        yieldText = try container.decodeIfPresent(String.self, forKey: .yieldText)
        prepTime = try container.decodeIfPresent(Double.self, forKey: .prepTime)
        cookTime = try container.decodeIfPresent(Double.self, forKey: .cookTime)
        totalTime = try container.decodeIfPresent(Double.self, forKey: .totalTime)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        ingredients = try container.decodeIfPresent([Line].self, forKey: .ingredients) ?? []
        steps = try container.decodeIfPresent([Line].self, forKey: .steps) ?? []
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

/// Read back from a recipe file that has recipi's extension. Only the
/// schema.org fields the extension doesn't repeat are read from the top
/// level; everything else comes from the extension.
struct JSONLDRecipeFile: Decodable {
    var identifier: String?
    var name: String?
    var description: String?
    var url: String?
    var author: String?
    var image: String?
    var dateCreated: String?
    var dateModified: String?
    var recipi: RecipiExtension

    enum CodingKeys: String, CodingKey {
        case identifier, name, description, url, author, image, dateCreated, dateModified
        case recipi = "recipi:extension"
    }

    private enum PersonKeys: String, CodingKey {
        case name
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        dateCreated = try container.decodeIfPresent(String.self, forKey: .dateCreated)
        dateModified = try container.decodeIfPresent(String.self, forKey: .dateModified)
        recipi = try container.decode(RecipiExtension.self, forKey: .recipi)

        // schema.org allows the author as a Person object or plain text.
        // Trying the object shape first is how the two are told apart.
        if container.contains(.author), try !container.decodeNil(forKey: .author) {
            if let person = try? container.nestedContainer(keyedBy: PersonKeys.self, forKey: .author) {
                author = try person.decodeIfPresent(String.self, forKey: .name)
            } else {
                author = try container.decode(String.self, forKey: .author)
            }
        } else {
            author = nil
        }
    }

    var backupRecipe: BackupRecipe {
        let id = UUID(uuidString: recipi.id) ?? identifier.flatMap(UUID.init(uuidString:)) ?? UUID()
        let now = Date.now
        let createdAt = (recipi.createdAt ?? dateCreated).flatMap(Timestamp.date(from:)) ?? now
        let updatedAt = (recipi.updatedAt ?? dateModified).flatMap(Timestamp.date(from:)) ?? createdAt
        var recipe = BackupRecipe(id: id, title: name ?? "", createdAt: createdAt, updatedAt: updatedAt)
        recipe.summary = description ?? ""
        recipe.sourceURL = url.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        recipe.author = author
        recipe.servings = recipi.servings
        recipe.yieldText = recipi.yieldText
        recipe.prepTime = recipi.prepTime
        recipe.cookTime = recipi.cookTime
        recipe.totalTime = recipi.totalTime
        recipe.notes = recipi.notes
        recipe.isFavorite = recipi.isFavorite
        recipe.tags = recipi.tags
        recipe.ingredients = recipi.ingredients.map(\.draftLine)
        recipe.steps = recipi.steps.map(\.draftLine)
        return recipe
    }
}
