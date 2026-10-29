import Foundation
import Observation
import RecipiKit
import SwiftData
import UniformTypeIdentifiers

@MainActor
@Observable
final class ShareImportModel {
    enum State {
        case importing
        /// Imported and shown for a look, with its photo, before saving.
        case preview(RecipeDraft)
        case saving
        case saved(title: String)
        /// The library already has a recipe from this page. `draft` is the
        /// import, when the page was read before the match was found.
        case alreadySaved(title: String, draft: RecipeDraft?)
        case failed(message: String)
    }

    private(set) var state: State = .importing
    /// The photos the page offers and the one picked, once imported.
    private(set) var photoChoice: ImportPhotoChoice?

    private let extensionContext: NSExtensionContext?
    @ObservationIgnored private var container: ModelContainer?

    init(extensionContext: NSExtensionContext?) {
        self.extensionContext = extensionContext
    }

    /// The page being imported, once a link was found in the shared item.
    @ObservationIgnored private var pageURL: URL?

    func run() async {
        guard let shared = await sharedURL() else {
            state = .failed(message: "There's no link here to import.")
            return
        }
        let url = SharedLink.pageURL(for: shared)
        pageURL = url
        // Already saved? Say so before reading the page; it also works
        // offline.
        if let existing = savedRecipe(from: url) {
            state = .alreadySaved(title: existing.title, draft: nil)
            return
        }
        await importPage(url, allowingDuplicate: false)
    }

    private func importPage(_ url: URL, allowingDuplicate: Bool) async {
        state = .importing
        do {
            let draft = try await RecipeImporter().importRecipe(from: url)
            // The page may have redirected to a link that's already saved.
            if !allowingDuplicate, let source = draft.sourceURL, let existing = savedRecipe(from: source) {
                state = .alreadySaved(title: existing.title, draft: draft)
                return
            }
            await showPreview(of: draft)
        } catch {
            state = .failed(message: Self.message(for: error))
        }
    }

    private func showPreview(of draft: RecipeDraft) async {
        let photoChoice = ImportPhotoChoice(draft: draft)
        self.photoChoice = photoChoice
        state = .preview(draft)
        await photoChoice.load()
    }

    /// Saves another copy of a recipe that's already in the library.
    func saveAnotherCopy() async {
        guard case .alreadySaved(_, let draft) = state else { return }
        if let draft {
            await showPreview(of: draft)
        } else if let pageURL {
            await importPage(pageURL, allowingDuplicate: true)
        }
    }

    /// The import error in words for the share sheet, which can't offer the
    /// app's "add it by hand".
    static func message(for error: any Error) -> String {
        switch error as? RecipeImportError {
        case .noRecipeFound?:
            "No recipe was found on that page. To add it by hand, open recipi."
        case .blockedBySite?:
            "That site didn't let recipi read the page. Try again in a little while, or open recipi to add it by hand."
        default:
            error.localizedDescription
        }
    }

    /// Whether the recipe can be saved now: it's imported and its best photo
    /// isn't still loading.
    var canSave: Bool {
        guard case .preview = state else { return false }
        return photoChoice?.isLoadingFirstPhoto != true
    }

    func save() async {
        guard case .preview(let draft) = state else { return }
        state = .saving
        do {
            let container = try openStore()
            let recipe = try RecipeImporter().save(draft, photoData: photoChoice?.selected?.data, into: container.mainContext)
            state = .saved(title: recipe.title)
            try? await Task.sleep(for: .seconds(1.2))
            finish()
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    func close() {
        switch state {
        case .saved, .alreadySaved:
            finish()
        default:
            extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    // MARK: - The library

    /// The shared store, opened once.
    private func openStore() throws -> ModelContainer {
        if let container { return container }
        let container = try RecipiStore.makeContainer()
        self.container = container
        return container
    }

    /// A saved recipe from the same page, if any. If the library can't be
    /// opened here, saving will say so; this just finds nothing.
    private func savedRecipe(from url: URL) -> Recipe? {
        guard let context = try? openStore().mainContext else { return nil }
        return try? Recipe.saved(from: url, in: context)
    }

    // MARK: - Reading the shared item

    private func sharedURL() async -> URL? {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = await loadURL(from: provider), url.scheme?.hasPrefix("http") == true {
                return url
            }
        }
        // Some apps share a link as text, sometimes with a title in front.
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            if let text = await loadText(from: provider), let url = SharedLink.firstWebURL(in: text) {
                return url
            }
        }
        return nil
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                continuation.resume(returning: text)
            }
        }
    }
}
