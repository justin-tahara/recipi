import Foundation
import Observation

/// The photos an imported recipe could use, loaded for preview, and the one
/// the person picked. Shared by the app's import sheet and the share
/// extension, which show it before saving.
@MainActor
@Observable
public final class ImportPhotoChoice {
    /// At most this many photos are loaded to choose from.
    public static let maxPhotos = 5

    /// The photos that loaded, best first.
    public private(set) var photos: [ImportedPhoto] = []
    /// The photo to save, or nil to save without one.
    public var selectedURL: URL?
    /// True until every candidate has been tried (or enough have loaded).
    public private(set) var isLoading = true

    private let candidates: [URL]
    private let importer: RecipeImporter

    public init(draft: RecipeDraft, importer: RecipeImporter = RecipeImporter()) {
        candidates = draft.imageCandidates.isEmpty ? [draft.imageURL].compactMap { $0 } : draft.imageCandidates
        self.importer = importer
    }

    /// The photo to save, if one is picked and loaded.
    public var selected: ImportedPhoto? {
        photos.first { $0.url == selectedURL }
    }

    /// Whether the best photo is still on its way. Saving waits for it, so
    /// the recipe doesn't end up without the photo the person was shown.
    public var isLoadingFirstPhoto: Bool {
        isLoading && photos.isEmpty
    }

    /// Loads the candidates in order. The first that loads is picked; ones
    /// that fail are skipped. With none, the recipe saves without a photo.
    public func load() async {
        guard isLoading, photos.isEmpty else { return }
        defer { isLoading = false }
        for url in candidates {
            guard photos.count < Self.maxPhotos, !Task.isCancelled else { break }
            guard let photo = await importer.fetchPhoto(at: url) else { continue }
            // The same picture is often listed under two addresses.
            guard !photos.contains(where: { $0.data == photo.data }) else { continue }
            photos.append(photo)
            // Pick the best one; leave later picks (including "No photo")
            // to the person.
            if photos.count == 1 {
                selectedURL = photo.url
            }
        }
    }
}
