import Foundation
import SwiftData
import Testing
@testable import RecipiKit

// MARK: - CRC-32 and zip

struct CRC32Tests {
    @Test func matchesKnownValues() {
        #expect(CRC32.checksum(Data()) == 0)
        // The standard check value for CRC-32/ISO-HDLC.
        #expect(CRC32.checksum(Data("123456789".utf8)) == 0xCBF4_3926)
        #expect(CRC32.checksum(Data("The quick brown fox jumps over the lazy dog".utf8)) == 0x414F_A339)
    }
}

struct ZipArchiveTests {
    /// Made with Python's zipfile: "stored.txt" stored, "deflated.txt"
    /// deflated.
    static let pythonMixed = """
        UEsDBBQAAAAAAABgXV0X2/M4DQAAAA0AAAAKAAAAc3RvcmVkLnR4dGhlbGxvIHN0b3JlZApQSwMEFAAAAAgAAGBdXbm47q4UAAAAGAEAAAwAAABkZWZsYXRlZC50eHTLSM3JyVdISU3LSSxJVcgY5UF5AFBLAQIUAxQAAAAAAABgXV0X2/M4DQAAAA0AAAAKAAAAAAAAAAAAAACAAQAAAABzdG9yZWQudHh0UEsBAhQDFAAAAAgAAGBdXbm47q4UAAAAGAEAAAwAAAAAAAAAAAAAAIABNQAAAGRlZmxhdGVkLnR4dFBLBQYAAAAAAgACAHIAAABzAAAAAAA=
        """

    /// Made with Python's zipfile: "bzip.txt" compressed with bzip2.
    static let pythonBzip2 = """
        UEsDBC4AAAAMAABgXV1RL5pJPQAAAHgAAAAIAAAAYnppcC50eHRCWmg5MUFZJlNZ6IJqrQAAHZmAQAAQABJkwBAgACClUaMnqEAMOJ2nyaTadJicTCYmJ+LuSKcKEh0QTVWgUEsBAi4DLgAAAAwAAGBdXVEvmkk9AAAAeAAAAAgAAAAAAAAAAAAAAIABAAAAAGJ6aXAudHh0UEsFBgAAAAABAAEANgAAAGMAAAAAAA==
        """

    private func decode(_ base64: String) throws -> Data {
        try #require(Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    @Test func writtenArchiveReadsBack() throws {
        let photo = Data((0..<2_000).map { UInt8(truncatingIfNeeded: $0 &* 31) })
        var writer = ZipWriter()
        try writer.addFile(named: "manifest.json", contents: Data(#"{"version":1}"#.utf8))
        try writer.addFile(named: "photos/ラーメン.jpg", contents: photo)
        try writer.addFile(named: "empty.txt", contents: Data())
        let archive = try writer.archive()

        #expect(Array(archive.prefix(4)) == [0x50, 0x4B, 0x03, 0x04])
        let reader = try ZipReader(data: archive)
        #expect(reader.entries.map(\.name) == ["manifest.json", "photos/ラーメン.jpg", "empty.txt"])
        #expect(try reader.contents(named: "manifest.json") == Data(#"{"version":1}"#.utf8))
        #expect(try reader.contents(named: "photos/ラーメン.jpg") == photo)
        #expect(try reader.contents(named: "empty.txt") == Data())
        #expect(try reader.contents(named: "missing.txt") == nil)
    }

    @Test func readsStoredAndDeflatedEntriesFromOtherTools() throws {
        let reader = try ZipReader(data: try decode(Self.pythonMixed))
        #expect(reader.entries.map(\.name) == ["stored.txt", "deflated.txt"])
        #expect(try reader.contents(named: "stored.txt") == Data("hello stored\n".utf8))
        #expect(try reader.contents(named: "deflated.txt") == Data(String(repeating: "hello deflate ", count: 20).utf8))
    }

    @Test func unsupportedCompressionFailsClearly() throws {
        let reader = try ZipReader(data: try decode(Self.pythonBzip2))
        let entry = try #require(reader.entry(named: "bzip.txt"))
        #expect(throws: ZipError.unsupportedCompression(method: 12)) {
            try reader.contents(of: entry)
        }
    }

    @Test func damagedContentsFailTheChecksum() throws {
        var writer = ZipWriter()
        try writer.addFile(named: "a.txt", contents: Data("abcdef".utf8))
        var archive = try writer.archive()
        // The data starts after the 30-byte local header and the name.
        archive[30 + 5] ^= 0xFF
        let reader = try ZipReader(data: archive)
        #expect(throws: ZipError.checksumMismatch(entry: "a.txt")) {
            try reader.contents(named: "a.txt")
        }
    }

    @Test func rejectsDataThatIsNotAZip() {
        #expect(throws: ZipError.notAZipArchive) {
            try ZipReader(data: Data("not a zip file, just some text".utf8))
        }
    }

    @Test func rejectsDuplicateNames() throws {
        var writer = ZipWriter()
        try writer.addFile(named: "a.txt", contents: Data())
        #expect(throws: ZipError.duplicateEntry("a.txt")) {
            try writer.addFile(named: "a.txt", contents: Data())
        }
    }
}

// MARK: - Backup format

/// Fixed values, with dates on whole milliseconds since the format keeps
/// milliseconds.
private func sampleBackups() -> [BackupRecipe] {
    var pasta = BackupRecipe(
        id: UUID(uuidString: "5A1C7F3E-2B4D-4E6F-8A9B-0C1D2E3F4A5B")!,
        title: "Pasta with tomato sauce",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000.25),
        updatedAt: Date(timeIntervalSince1970: 1_750_000_000.5)
    )
    pasta.summary = "A weeknight pasta."
    pasta.sourceURL = URL(string: "https://example.com/pasta")
    pasta.author = "Sam Cook"
    pasta.servings = 4
    pasta.yieldText = "4 bowls"
    pasta.prepTime = 600
    pasta.cookTime = 1_230
    pasta.totalTime = 1_830.5
    pasta.notes = "Add chilli if you like.\nKeeps <3 days> & \"tastes\" better / cold."
    pasta.isFavorite = true
    pasta.ingredients = [
        .init("400 g spaghetti"),
        .init("2 tbsp olive oil", section: "For the sauce"),
        .init("1 (14 oz) can tomatoes", section: "For the sauce"),
        .init("Parmesan", section: "To serve"),
    ]
    pasta.steps = [
        .init("Warm the oil.", section: "Make the sauce"),
        .init("Add the tomatoes.", section: "Make the sauce"),
        .init("Boil the pasta."),
        .init("Serve hot, or cold the next day."),
    ]
    pasta.tags = ["Dinner", "Quick", "Vegetarian"]
    pasta.photoData = Data([0xFF, 0xD8, 0xFF, 0xE0] + (0..<500).map { UInt8(truncatingIfNeeded: $0) })

    var toast = BackupRecipe(
        id: UUID(uuidString: "0B9E8D7C-6A5B-4C3D-9E2F-1A0B9C8D7E6F")!,
        title: "Toast",
        createdAt: Date(timeIntervalSince1970: 1_600_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_600_000_000)
    )
    toast.steps = [.init("Toast the bread.")]

    var onigiri = BackupRecipe(
        id: UUID(uuidString: "C3D4E5F6-A7B8-4C9D-8E0F-112233445566")!,
        title: "おにぎり",
        createdAt: Date(timeIntervalSince1970: 1_650_000_000.125),
        updatedAt: Date(timeIntervalSince1970: 1_650_000_100)
    )
    onigiri.ingredients = [.init("2 cups cooked rice"), .init("1 umeboshi")]
    onigiri.tags = ["Lunch"]
    onigiri.photoData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3])
    return [pasta, toast, onigiri]
}

struct BackupFormatTests {
    @Test func archiveRoundTripKeepsEveryFieldAndPhoto() throws {
        let backups = sampleBackups()
        let archive = try RecipiBackup.makeArchive(of: backups, appVersion: "0.1.0")
        let contents = try RecipiBackup.read(archive)
        #expect(contents.unreadableFiles.isEmpty)
        #expect(contents.recipes == backups)
        #expect(contents.recipes[0].photoData == backups[0].photoData)
    }

    @Test func archiveLayout() throws {
        let archive = try RecipiBackup.makeArchive(of: sampleBackups())
        let reader = try ZipReader(data: archive)
        #expect(reader.entries.map(\.name) == [
            "manifest.json",
            "photos/5a1c7f3e-2b4d-4e6f-8a9b-0c1d2e3f4a5b.jpg",
            "recipes/5a1c7f3e-2b4d-4e6f-8a9b-0c1d2e3f4a5b.json",
            "recipes/0b9e8d7c-6a5b-4c3d-9e2f-1a0b9c8d7e6f.json",
            "photos/c3d4e5f6-a7b8-4c9d-8e0f-112233445566.png",
            "recipes/c3d4e5f6-a7b8-4c9d-8e0f-112233445566.json",
        ])
        let manifestData = try #require(try reader.contents(named: "manifest.json"))
        let manifest = try #require(try JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        #expect(manifest["format"] as? String == "recipi-backup")
        #expect(manifest["version"] as? Int == 1)
        #expect(manifest["recipeCount"] as? Int == 3)
    }

    @Test func recipeFileIsSchemaOrgJSONLD() throws {
        let pasta = sampleBackups()[0]
        let json = try RecipiBackup.jsonLD(for: pasta, photoPath: "photos/pasta.jpg")
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(object["@context"] as? String == "https://schema.org")
        #expect(object["@type"] as? String == "Recipe")
        #expect(object["name"] as? String == "Pasta with tomato sauce")
        #expect(object["image"] as? String == "photos/pasta.jpg")
        #expect(object["prepTime"] as? String == "PT10M")
        #expect(object["cookTime"] as? String == "PT20M30S")
        #expect(object["recipeYield"] as? String == "4 bowls")
        #expect(object["keywords"] as? String == "Dinner, Quick, Vegetarian")
        #expect(object["dateCreated"] as? String == "2023-11-14T22:13:20.250Z")

        // Another app reading it, played here by recipi's own web importer.
        let node = try #require(SchemaRecipeParser.findRecipe(in: object))
        let draft = try #require(SchemaRecipeParser.draft(from: node, sourceURL: nil))
        #expect(draft.title == pasta.title)
        #expect(draft.sourceURL == pasta.sourceURL)
        #expect(draft.author == "Sam Cook")
        #expect(draft.ingredients.map(\.text) == pasta.ingredients.map(\.text))
        #expect(draft.steps == pasta.steps)
        #expect(draft.prepTime == 600)
    }

    @Test func singleSharedRecipeReadsBackWithoutPhoto() throws {
        let pasta = sampleBackups()[0]
        let contents = try RecipiBackup.read(try RecipiBackup.jsonLD(for: pasta))
        var expected = pasta
        expected.photoData = nil
        #expect(contents.recipes == [expected])
    }

    @Test func unknownKeysAndMissingListsAreFine() throws {
        // What a later version might write: an extra list (a cook log) and
        // extra keys, with lists this version expects left out.
        let json = """
            {
              "@context": "https://schema.org",
              "@type": "Recipe",
              "name": "Miso soup",
              "author": "Aiko",
              "somethingNew": {"nested": [1, 2, 3]},
              "recipi:extension": {
                "id": "9f0e1d2c-3b4a-4958-8776-655443322110",
                "isFavorite": true,
                "cookLog": [{"date": "2026-10-01T18:00:00Z", "note": "Less miso."}],
                "futureField": 42
              }
            }
            """
        let contents = try RecipiBackup.read(Data(json.utf8))
        let recipe = try #require(contents.recipes.first)
        #expect(recipe.id == UUID(uuidString: "9F0E1D2C-3B4A-4958-8776-655443322110"))
        #expect(recipe.title == "Miso soup")
        #expect(recipe.author == "Aiko")
        #expect(recipe.isFavorite)
        #expect(recipe.ingredients.isEmpty)
        #expect(recipe.steps.isEmpty)
        #expect(recipe.tags.isEmpty)
        #expect(recipe.notes.isEmpty)
    }

    @Test func otherAppsJSONLDIsReadLikeAWebImport() throws {
        let json = """
            {"@context": "https://schema.org", "@graph": [{"@type": "Recipe", "name": "Flatbread",
              "recipeIngredient": ["2 cups flour", "1 cup yogurt"],
              "recipeInstructions": [{"@type": "HowToStep", "text": "Mix."}, {"@type": "HowToStep", "text": "Cook."}],
              "keywords": "bread, quick"}]}
            """
        let recipe = try #require(try RecipiBackup.read(Data(json.utf8)).recipes.first)
        #expect(recipe.title == "Flatbread")
        #expect(recipe.ingredients.map(\.text) == ["2 cups flour", "1 cup yogurt"])
        #expect(recipe.steps.map(\.text) == ["Mix.", "Cook."])
        #expect(recipe.tags == ["bread", "quick"])
    }

    @Test func newerFormatIsRefused() throws {
        var writer = ZipWriter()
        try writer.addFile(named: "manifest.json", contents: Data(#"{"format":"recipi-backup","version":99}"#.utf8))
        #expect(throws: BackupError.newerFormat(version: 99)) {
            try RecipiBackup.read(try writer.archive())
        }
    }

    @Test func otherZipsAreNotBackups() throws {
        var writer = ZipWriter()
        try writer.addFile(named: "notes.txt", contents: Data("hello".utf8))
        #expect(throws: BackupError.notABackup) {
            try RecipiBackup.read(try writer.archive())
        }
        #expect(throws: BackupError.notARecipe) {
            try RecipiBackup.read(Data("plain text".utf8))
        }
    }

    @Test func rezippedBackupInsideAFolderStillReads() throws {
        // Like unzipping a backup in Finder and compressing the folder.
        let original = try ZipReader(data: try RecipiBackup.makeArchive(of: sampleBackups()))
        var writer = ZipWriter()
        try writer.addFile(named: "recipi backup/", contents: Data())
        for entry in original.entries {
            try writer.addFile(named: "recipi backup/" + entry.name, contents: try original.contents(of: entry))
        }
        try writer.addFile(named: "__MACOSX/recipi backup/recipes/._junk.json", contents: Data([0, 5, 22]))
        let contents = try RecipiBackup.read(try writer.archive())
        #expect(contents.recipes == sampleBackups())
        #expect(contents.unreadableFiles.isEmpty)
    }

    @Test func unreadableRecipeAndMissingPhotoAreReported() throws {
        var writer = ZipWriter()
        try writer.addFile(named: "manifest.json", contents: Data(#"{"format":"recipi-backup","version":1}"#.utf8))
        try writer.addFile(named: "recipes/broken.json", contents: Data("{".utf8))
        let pasta = sampleBackups()[0]
        try writer.addFile(named: "recipes/pasta.json", contents: try RecipiBackup.jsonLD(for: pasta, photoPath: "photos/gone.jpg"))
        let contents = try RecipiBackup.read(try writer.archive())
        var expected = pasta
        expected.photoData = nil
        #expect(contents.recipes == [expected])
        #expect(contents.unreadableFiles == ["recipes/broken.json", "photos/gone.jpg"])
    }

    @Test func durationsAsISO8601() {
        #expect(DurationText.iso8601(0) == "PT0S")
        #expect(DurationText.iso8601(45) == "PT45S")
        #expect(DurationText.iso8601(5_400) == "PT1H30M")
        #expect(DurationText.iso8601(-1) == nil)
    }
}

// MARK: - Library round trip

/// Export from one in-memory store and restore into another.
@Suite(.serialized)
struct BackupStoreTests {
    private func insertSamples(into context: ModelContext) {
        for backup in sampleBackups() {
            Recipe.insert(from: backup, into: context)
        }
    }

    private func snapshotsSortedByTitle(_ context: ModelContext) throws -> [BackupRecipe] {
        let recipes = try context.fetch(FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.title)]))
        return BackupRecipe.snapshots(of: recipes)
    }

    @Test func exportThenRestoreKeepsEveryFieldAndPhoto() throws {
        let source = ModelContext(try RecipiStore.makeContainer(inMemory: true))
        insertSamples(into: source)
        try source.save()
        let exported = try snapshotsSortedByTitle(source)
        #expect(exported.count == 3)

        let archive = try RecipiBackup.makeArchive(of: exported)
        let contents = try RecipiBackup.read(archive)

        let destination = ModelContext(try RecipiStore.makeContainer(inMemory: true))
        let summary = try RecipiBackup.restore(contents.recipes, into: destination)
        #expect(summary == RestoreSummary(restored: 3, skippedDuplicates: 0))

        let restored = try snapshotsSortedByTitle(destination)
        #expect(restored == exported)
        let photosByID = Dictionary(uniqueKeysWithValues: restored.map { ($0.id, $0.photoData) })
        let expectedPhotos = Dictionary(uniqueKeysWithValues: sampleBackups().map { ($0.id, $0.photoData) })
        #expect(photosByID == expectedPhotos)
        #expect(try destination.fetchCount(FetchDescriptor<Tag>()) == 4)
    }

    @Test func restoringTwiceSkipsDuplicates() throws {
        let context = ModelContext(try RecipiStore.makeContainer(inMemory: true))
        let backups = sampleBackups()
        #expect(try RecipiBackup.restore(backups, into: context) == RestoreSummary(restored: 3, skippedDuplicates: 0))
        #expect(try RecipiBackup.restore(backups, into: context) == RestoreSummary(restored: 0, skippedDuplicates: 3))
        #expect(try context.fetchCount(FetchDescriptor<Recipe>()) == 3)
    }

    @Test func sameSourceLinkCountsAsDuplicate() throws {
        let context = ModelContext(try RecipiStore.makeContainer(inMemory: true))
        var draft = RecipeDraft(title: "Pasta (imported again)")
        draft.sourceURL = URL(string: "https://EXAMPLE.com/pasta/")
        draft.steps = [.init("Cook.")]
        Recipe.insert(from: draft, into: context)
        try context.save()

        let summary = try RecipiBackup.restore(sampleBackups(), into: context)
        #expect(summary == RestoreSummary(restored: 2, skippedDuplicates: 1))
    }

    @Test func olderRecipesGetStableUniqueIDsOnExport() throws {
        let context = ModelContext(try RecipiStore.makeContainer(inMemory: true))
        let older = Recipe(title: "From before IDs")
        older.uuid = nil
        let shared = UUID()
        let first = Recipe(title: "Twin A")
        first.uuid = shared
        let second = Recipe(title: "Twin B")
        second.uuid = shared
        for recipe in [older, first, second] { context.insert(recipe) }
        try context.save()

        let snapshots = try snapshotsSortedByTitle(context)
        #expect(Set(snapshots.map(\.id)).count == 3)
        #expect(older.uuid == snapshots[0].id)
        try context.save()
        // A second export uses the same IDs.
        #expect(try snapshotsSortedByTitle(context).map(\.id) == snapshots.map(\.id))
    }
}
