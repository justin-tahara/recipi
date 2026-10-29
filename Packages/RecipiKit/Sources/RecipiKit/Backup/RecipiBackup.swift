import Foundation

/// recipi's backup format (see docs/backup-format.md): a zip with a
/// manifest, one schema.org `Recipe` JSON-LD file per recipe, and the
/// photos. Everything recipi knows that schema.org has no place for sits
/// under the `recipi:extension` key of each recipe file, so a restore keeps
/// every field while other apps can still read the rest.
public enum RecipiBackup {
    /// Bump only for a change older versions can't read. Adding a key does
    /// not need a bump: readers ignore keys they don't know and treat a
    /// missing list as empty.
    public static let formatVersion = 1
    public static let formatName = "recipi-backup"
    public static let extensionKey = "recipi:extension"
    static let manifestFileName = "manifest.json"
    static let recipesFolder = "recipes/"
    static let photosFolder = "photos/"

    // MARK: Writing

    /// The whole backup as zip data. Each recipe's `id` must be unique,
    /// which `BackupRecipe.snapshots(of:)` makes sure of.
    public static func makeArchive(
        of recipes: [BackupRecipe],
        exportedAt: Date = .now,
        appVersion: String? = nil
    ) throws -> Data {
        var writer = ZipWriter(modificationDate: exportedAt)
        let manifest = Manifest(
            format: formatName,
            version: formatVersion,
            exportedAt: Timestamp.string(from: exportedAt),
            appVersion: appVersion,
            recipeCount: recipes.count
        )
        try writer.addFile(named: manifestFileName, contents: try makeEncoder().encode(manifest))
        for recipe in recipes {
            let baseName = recipe.id.uuidString.lowercased()
            var photoPath: String?
            if let photo = recipe.photoData, !photo.isEmpty {
                let path = "\(photosFolder)\(baseName).\(photoFileExtension(for: photo))"
                try writer.addFile(named: path, contents: photo)
                photoPath = path
            }
            let json = try jsonLD(for: recipe, photoPath: photoPath)
            try writer.addFile(named: "\(recipesFolder)\(baseName).json", contents: json)
        }
        return try writer.archive()
    }

    /// One recipe as a standalone JSON-LD file, for sharing. It has no
    /// photo, since a single file can't carry one alongside.
    public static func jsonLD(for recipe: BackupRecipe) throws -> Data {
        try jsonLD(for: recipe, photoPath: nil)
    }

    static func jsonLD(for recipe: BackupRecipe, photoPath: String?) throws -> Data {
        try makeEncoder().encode(JSONLDRecipe(recipe, photoPath: photoPath))
    }

    // MARK: Reading

    /// Reads a backup zip, or a single recipe JSON file like the ones shared
    /// from a recipe's menu.
    public static func read(_ data: Data) throws -> BackupContents {
        if data.starts(with: [0x50, 0x4B]) { // "PK", a zip
            return try readArchive(data)
        }
        let (recipe, _) = try decodeRecipe(from: data)
        return BackupContents(recipes: [recipe], unreadableFiles: [])
    }

    static func readArchive(_ data: Data) throws -> BackupContents {
        let zip: ZipReader
        do {
            zip = try ZipReader(data: data)
        } catch ZipError.notAZipArchive {
            throw BackupError.notABackup
        }

        // Skip folders and the resource-fork copies Finder adds when it
        // zips a folder ("__MACOSX/…", "._name").
        let files = zip.entries.filter { entry in
            let components = entry.name.split(separator: "/")
            return !entry.isDirectory
                && !components.contains("__MACOSX")
                && components.last?.hasPrefix("._") == false
        }

        // A backup that was unzipped and zipped again sits inside a folder,
        // so everything is read relative to wherever the manifest is.
        let manifestEntry = files
            .filter { $0.name == manifestFileName || $0.name.hasSuffix("/" + manifestFileName) }
            .min { $0.name.count < $1.name.count }
        var root = ""
        if let manifestEntry {
            root = String(manifestEntry.name.dropLast(manifestFileName.count))
            let manifest: Manifest
            do {
                manifest = try JSONDecoder().decode(Manifest.self, from: try zip.contents(of: manifestEntry))
            } catch let error as ZipError {
                throw error
            } catch {
                throw BackupError.notABackup
            }
            guard manifest.format == formatName else { throw BackupError.notABackup }
            guard manifest.version <= formatVersion else {
                throw BackupError.newerFormat(version: manifest.version)
            }
        }

        let recipeEntries = files.filter {
            $0.name.hasPrefix(root + recipesFolder) && $0.name.hasSuffix(".json")
        }
        guard manifestEntry != nil || !recipeEntries.isEmpty else { throw BackupError.notABackup }

        var recipes: [BackupRecipe] = []
        var unreadable: [String] = []
        for entry in recipeEntries {
            let decoded: (BackupRecipe, imagePath: String?)
            do {
                decoded = try decodeRecipe(from: try zip.contents(of: entry))
            } catch {
                unreadable.append(entry.name)
                continue
            }
            var recipe = decoded.0
            let imagePath = decoded.imagePath
            // A photo that's missing or damaged doesn't stop its recipe
            // from coming back; it's listed as unreadable instead.
            if let imagePath, isArchivePath(imagePath) {
                let photoName = root + imagePath
                do {
                    if let photo = try zip.contents(named: photoName) {
                        recipe.photoData = photo
                    } else {
                        unreadable.append(photoName)
                    }
                } catch {
                    unreadable.append(photoName)
                }
            }
            recipes.append(recipe)
        }
        return BackupContents(recipes: recipes, unreadableFiles: unreadable)
    }

    /// A recipe and the archive path of its photo, if it names one. Files
    /// without recipi's extension (JSON-LD from another app) are read with
    /// the same parser as web imports.
    static func decodeRecipe(from json: Data) throws -> (BackupRecipe, imagePath: String?) {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: json)
        } catch {
            throw BackupError.notARecipe
        }
        if let dictionary = object as? [String: Any], dictionary[extensionKey] != nil {
            let file: JSONLDRecipeFile
            do {
                file = try JSONDecoder().decode(JSONLDRecipeFile.self, from: json)
            } catch {
                throw BackupError.notARecipe
            }
            return (file.backupRecipe, file.image)
        }
        guard let node = SchemaRecipeParser.findRecipe(in: object),
              let draft = SchemaRecipeParser.draft(from: node, sourceURL: nil) else {
            throw BackupError.notARecipe
        }
        return (BackupRecipe(draft: draft), nil)
    }

    // MARK: Helpers

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// A relative path inside the archive, not a web address or a path that
    /// climbs out of it.
    private static func isArchivePath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("://") && !path.split(separator: "/").contains("..")
    }

    /// Photos keep their bytes as stored; the extension follows the format.
    static func photoFileExtension(for data: Data) -> String {
        let header = [UInt8](data.prefix(12))
        func matches(_ bytes: [UInt8], at offset: Int = 0) -> Bool {
            header.count >= offset + bytes.count && Array(header[offset..<(offset + bytes.count)]) == bytes
        }
        if matches([0xFF, 0xD8, 0xFF]) { return "jpg" }
        if matches([0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if matches(Array("GIF8".utf8)) { return "gif" }
        if matches(Array("RIFF".utf8)), matches(Array("WEBP".utf8), at: 8) { return "webp" }
        if matches(Array("ftyp".utf8), at: 4) { return "heic" }
        return "jpg"
    }
}

/// What a backup file held.
public struct BackupContents: Sendable {
    public var recipes: [BackupRecipe]
    /// Archive paths of files that were there but couldn't be read.
    public var unreadableFiles: [String]

    public init(recipes: [BackupRecipe], unreadableFiles: [String]) {
        self.recipes = recipes
        self.unreadableFiles = unreadableFiles
    }
}

public enum BackupError: Error, Equatable, LocalizedError {
    case notABackup
    case newerFormat(version: Int)
    case notARecipe

    public var errorDescription: String? {
        switch self {
        case .notABackup:
            "That file isn't a recipi backup."
        case .newerFormat:
            "This backup was made by a newer version of recipi. Update recipi to restore it."
        case .notARecipe:
            "That file doesn't contain a recipe recipi can read."
        }
    }
}

// MARK: - Manifest

struct Manifest: Codable {
    var format: String
    var version: Int
    var exportedAt: String?
    var appVersion: String?
    var recipeCount: Int?
}

// MARK: - Times

enum Timestamp {
    /// ISO 8601 in UTC with milliseconds, e.g. "2026-10-29T18:04:05.250Z".
    static func string(from date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(trimmed) {
            return date
        }
        // Hand-edited or other apps' files may leave out the fraction.
        return try? Date.ISO8601FormatStyle().parse(trimmed)
    }
}

enum DurationText {
    /// Seconds as an ISO 8601 duration for schema.org, e.g. "PT1H30M".
    static func iso8601(_ seconds: TimeInterval) -> String? {
        guard seconds.isFinite, seconds >= 0 else { return nil }
        let total = Int(seconds.rounded())
        let hours = total / 3_600
        let minutes = total % 3_600 / 60
        let remainder = total % 60
        var text = "PT"
        if hours > 0 { text += "\(hours)H" }
        if minutes > 0 { text += "\(minutes)M" }
        if remainder > 0 || (hours == 0 && minutes == 0) { text += "\(remainder)S" }
        return text
    }
}

extension BackupRecipe {
    /// A recipe from another app's JSON-LD, read the way web imports are.
    init(draft: RecipeDraft) {
        self.init(title: draft.title)
        summary = draft.summary
        sourceURL = draft.sourceURL
        author = draft.author
        servings = draft.servings
        yieldText = draft.yieldText
        prepTime = draft.prepTime
        cookTime = draft.cookTime
        totalTime = draft.totalTime
        ingredients = draft.ingredients
        steps = draft.steps
        tags = draft.tags
    }
}
