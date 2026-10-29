import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Settings' Backup section: save the whole library as a .zip anywhere the
/// Files picker reaches (iCloud Drive, On My iPhone, Google Drive, Dropbox),
/// and restore one. Everything happens on the device; the picker's provider
/// does any uploading. The format is in docs/backup-format.md.
struct BackupSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportDocument: BackupDocument?
    @State private var exportedCount = 0
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isWorking = false
    @State private var outcome: Outcome?

    var body: some View {
        Section {
            // Each picker hangs off its own button: two file pickers on one
            // view can stop each other from showing.
            Button {
                Task { await prepareExport() }
            } label: {
                Label("Export library", systemImage: "square.and.arrow.up")
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .disabled(isWorking)
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .zip,
                defaultFilename: Self.defaultFilename()
            ) { result in
                finishExport(result)
            }

            Button {
                outcome = nil
                isImporting = true
            } label: {
                Label("Restore from backup", systemImage: "arrow.down.doc")
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .disabled(isWorking)
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.zip, .json]) { result in
                switch result {
                case .success(let url):
                    Task { await restore(from: url) }
                case .failure(let error):
                    outcome = .failure(error.localizedDescription)
                }
            }

            if isWorking {
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                    Text("Working…")
                        .font(Theme.Fonts.meta)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }

            if let outcome {
                Callout(symbol: outcome.symbol, color: outcome.color) {
                    Text(outcome.message)
                        .font(Theme.Fonts.meta)
                }
                .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.xs, bottom: Theme.Spacing.xs, trailing: Theme.Spacing.xs))
                .transition(.opacity)
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Saves every recipe with its photos, notes, tags and cook history as a .zip you can keep in Files, iCloud Drive, Google Drive or Dropbox. Each recipe is a schema.org file other apps can read. Restoring adds only recipes you don't already have.")
        }
        .motion(Motion.snappy, value: outcome)
        .motion(Motion.snappy, value: isWorking)
    }

    // MARK: Export

    private func prepareExport() async {
        outcome = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let recipes = try modelContext.fetch(FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.title)]))
            guard !recipes.isEmpty else {
                outcome = .info("There are no recipes to back up yet.")
                return
            }
            let snapshots = BackupRecipe.snapshots(of: recipes)
            // Keep any IDs just given to older recipes, so the next backup
            // and restore recognize them.
            if modelContext.hasChanges {
                try modelContext.save()
            }
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let data = try await Task.detached(priority: .userInitiated) {
                try RecipiBackup.makeArchive(of: snapshots, appVersion: appVersion)
            }.value
            exportedCount = snapshots.count
            exportDocument = BackupDocument(data: data)
            isExporting = true
        } catch {
            outcome = .failure("Couldn't make the backup. \(error.localizedDescription)")
        }
    }

    private func finishExport(_ result: Result<URL, any Error>) {
        exportDocument = nil
        switch result {
        case .success(let url):
            outcome = .success("Saved \(Self.recipes(exportedCount)) to “\(url.lastPathComponent)”.")
        case .failure(let error):
            outcome = .failure("Couldn't save the backup. \(error.localizedDescription)")
        }
    }

    private static func defaultFilename() -> String {
        "recipi backup \(Date.now.formatted(.iso8601.year().month().day()))"
    }

    // MARK: Restore

    private func restore(from url: URL) async {
        outcome = nil
        isWorking = true
        defer { isWorking = false }
        do {
            // Reading and unzipping can take a moment for a big library, so
            // it happens off the main thread; inserting needs the main one.
            let contents = try await Task.detached(priority: .userInitiated) {
                try RecipiBackup.read(try BackupFileReader.read(url))
            }.value
            let summary = try RecipiBackup.restore(contents.recipes, into: modelContext)
            outcome = .success(Self.message(for: summary, unreadable: contents.unreadableFiles.count))
        } catch {
            outcome = .failure(error.localizedDescription)
        }
    }

    private static func message(for summary: RestoreSummary, unreadable: Int) -> String {
        var parts: [String] = []
        if summary.restored > 0 {
            parts.append("Restored \(recipes(summary.restored)).")
        } else if summary.skippedDuplicates == 0 {
            parts.append("The backup had no recipes to restore.")
        }
        if summary.skippedDuplicates > 0 {
            parts.append(summary.restored == 0
                ? "All \(recipes(summary.skippedDuplicates)) in the backup are already in your library."
                : "Skipped \(summary.skippedDuplicates) already in your library.")
        }
        if unreadable > 0 {
            parts.append(unreadable == 1 ? "1 file couldn't be read." : "\(unreadable) files couldn't be read.")
        }
        return parts.joined(separator: " ")
    }

    private static func recipes(_ count: Int) -> String {
        count == 1 ? "1 recipe" : "\(count) recipes"
    }

    // MARK: Outcome

    private enum Outcome: Equatable {
        case success(String)
        case info(String)
        case failure(String)

        var message: String {
            switch self {
            case .success(let text), .info(let text), .failure(let text): text
            }
        }

        var symbol: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .info: "info.circle.fill"
            case .failure: "exclamationmark.triangle.fill"
            }
        }

        var color: TagColor {
            switch self {
            case .success: .green
            case .info: .blue
            case .failure: .red
            }
        }
    }
}

/// The backup zip, handed to the Files picker to save.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Reads a file the person picked, which may live with another app's file
/// provider (Google Drive, Dropbox) and need downloading first.
private enum BackupFileReader {
    static func read(_ url: URL) throws -> Data {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        var coordinationError: NSError?
        var result: Result<Data, any Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            result = Result { try Data(contentsOf: readURL) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }
}
