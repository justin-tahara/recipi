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
        case saved(title: String)
        case failed(message: String)
    }

    private(set) var state: State = .importing

    private let extensionContext: NSExtensionContext?
    @ObservationIgnored private var container: ModelContainer?

    init(extensionContext: NSExtensionContext?) {
        self.extensionContext = extensionContext
    }

    func run() async {
        guard let url = await sharedURL() else {
            state = .failed(message: "There's no link here to import.")
            return
        }
        do {
            let container = try RecipiStore.makeContainer()
            self.container = container
            let recipe = try await RecipeImporter().saveRecipe(from: url, into: container.mainContext)
            state = .saved(title: recipe.title)
            try? await Task.sleep(for: .seconds(1.2))
            finish()
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    func close() {
        if case .saved = state {
            finish()
        } else {
            extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
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
