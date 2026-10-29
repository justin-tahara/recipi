import PhotosUI
import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

/// "I made this": records a cook with an optional photo and a note.
struct LogCookSheet: View {
    let recipe: Recipe
    /// "Cancel" from the recipe page, "Skip" at the end of cooking mode.
    var cancelTitle = "Cancel"
    var onLogged: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cookedAt = Date.now
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isLoadingPhoto = false
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    photoSection
                    Section {
                        DatePicker("Cooked", selection: $cookedAt, in: ...Date.now, displayedComponents: .date)
                        TextField("Notes for next time", text: $note, axis: .vertical)
                            .lineLimit(2...6)
                            .accessibilityLabel("Notes")
                    }
                }
                .listRowBackground(Theme.Colors.elevated)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.surface)
            .motion(Motion.smooth, value: photoData != nil)
            .navigationTitle("I made this")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(isLoadingPhoto)
                }
            }
            .onChange(of: photoItem) {
                Task { await loadPhoto() }
            }
        }
        .tint(Theme.Colors.accent)
    }

    private var photoSection: some View {
        Section {
            if let photoData {
                RecipePhoto(data: photoData, title: recipe.title)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            // PhotosPicker's label closure is Sendable, so read the
            // main-actor state here rather than inside it.
            let photoLabel = photoData == nil ? "Add a photo" : "Change photo"
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photoLabel, systemImage: "camera")
            }
            if isLoadingPhoto {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
            if photoData != nil {
                Button("Remove photo", systemImage: "trash", role: .destructive) {
                    photoItem = nil
                    withMotion(Motion.smooth, reduceMotion: reduceMotion) {
                        photoData = nil
                    }
                }
            }
        } header: {
            Text("How it came out")
        }
    }

    private func loadPhoto() async {
        guard let photoItem else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        guard let data = try? await photoItem.loadTransferable(type: Data.self) else { return }
        // Same downscale as imported photos, so cooks stay small in iCloud.
        let prepared = RecipePhotoProcessor.prepare(data) ?? data
        withMotion(Motion.smooth, reduceMotion: reduceMotion) {
            photoData = prepared
        }
    }

    private func save() {
        recipe.logCook(on: cookedAt, photoData: photoData, note: note, in: modelContext)
        onLogged()
        dismiss()
    }
}
