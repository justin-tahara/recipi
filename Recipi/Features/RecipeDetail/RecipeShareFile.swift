import CoreTransferable
import Foundation
import RecipiKit
import UniformTypeIdentifiers

/// One recipe as a schema.org JSON-LD file, for the share sheet. Other
/// recipe apps can read it, and recipi restores it from Settings. It leaves
/// out the photo and the cook history.
struct RecipeShareFile: Transferable {
    let recipe: BackupRecipe

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let data = try RecipiBackup.jsonLD(for: file.recipe)
            // A folder of its own, so the file can carry the recipe's name.
            let folder = FileManager.default.temporaryDirectory
                .appending(path: "Shared recipes", directoryHint: .isDirectory)
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: "\(file.fileName).json", directoryHint: .notDirectory)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }

    private var fileName: String {
        let cleaned = recipe.title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|").union(.newlines))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Recipe" : String(cleaned.prefix(80))
    }
}
