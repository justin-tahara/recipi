import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI
import UIKit

struct ImportRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    /// The imported recipe, shown for a look (and a photo pick) before saving.
    @State private var draft: RecipeDraft?
    @State private var photoChoice: ImportPhotoChoice?
    @FocusState private var isFieldFocused: Bool
    @ScaledMetric(relativeTo: .title2) private var iconTileSize: CGFloat = 56

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Image(systemName: "link")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(TagColor.blue.foreground)
                        .frame(width: iconTileSize, height: iconTileSize)
                        .background(TagColor.blue.background, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Import from a link")
                            .font(Theme.Fonts.sectionTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("Paste a link to a recipe. You can also share a page to recipi straight from Safari.")
                            .font(Theme.Fonts.meta)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    linkField

                    if let errorMessage {
                        Callout(symbol: "exclamationmark.triangle.fill", color: .red) {
                            Text(errorMessage)
                                .font(Theme.Fonts.meta)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let draft, let photoChoice {
                        ImportPreview(draft: draft, photos: photoChoice)
                            .transition(.opacity)
                    }

                    Button {
                        if draft == nil {
                            Task { await importRecipe() }
                        } else {
                            save()
                        }
                    } label: {
                        if isImporting {
                            ProgressView()
                                .tint(Theme.Colors.onAccent)
                                .accessibilityLabel("Importing")
                        } else {
                            Text(draft == nil ? "Import recipe" : "Save recipe")
                        }
                    }
                    .buttonStyle(.recipiPrimary)
                    .disabled(isPrimaryDisabled)
                }
                .padding(Theme.Spacing.page)
                .motion(Motion.snappy, value: errorMessage)
                .motion(Motion.smooth, value: draft)
            }
            .background(Theme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isFieldFocused = true }
            // A new link means a new import.
            .onChange(of: urlText) {
                draft = nil
                photoChoice = nil
            }
            .onChange(of: errorMessage) { _, message in
                if let message {
                    AccessibilityNotification.Announcement(message).post()
                }
            }
            .task(id: photoChoice.map { ObjectIdentifier($0) }) {
                await photoChoice?.load()
            }
        }
        .tint(Theme.Colors.accent)
    }

    private var linkField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "globe")
                .foregroundStyle(Theme.Colors.textTertiary)
                .accessibilityHidden(true)
            TextField("https://", text: $urlText)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($isFieldFocused)
                .onSubmit {
                    if draft == nil { Task { await importRecipe() } }
                }
            if !urlText.isEmpty {
                Button {
                    urlText = ""
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // A full 44 pt target without making the field taller.
                .padding(.vertical, -Theme.Spacing.sm)
                .accessibilityLabel("Clear link")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 14)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .strokeBorder(isFieldFocused ? Theme.Colors.accent : Theme.Colors.border, lineWidth: isFieldFocused ? 1.5 : 0.5)
        }
        .motion(Motion.snappy, value: isFieldFocused)
    }

    /// The link in the field. Pasted text with a title or comment around the
    /// link works too.
    private var url: URL? {
        SharedLink.firstWebURL(in: urlText)
    }

    private var isPrimaryDisabled: Bool {
        if isImporting { return true }
        if draft == nil { return url == nil }
        // Wait for the best photo, so the recipe isn't saved without the
        // photo that's about to appear.
        return photoChoice?.isLoadingFirstPhoto == true
    }

    private func importRecipe() async {
        guard let url, !isImporting else { return }
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            let draft = try await RecipeImporter().importRecipe(from: url)
            photoChoice = ImportPhotoChoice(draft: draft)
            self.draft = draft
            isFieldFocused = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let draft else { return }
        do {
            try RecipeImporter().save(draft, photoData: photoChoice?.selected?.data, into: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// The imported recipe before it's saved: its photo, a choice of photos when
/// the page offers several, and what was found.
private struct ImportPreview: View {
    let draft: RecipeDraft
    @Bindable var photos: ImportPhotoChoice

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Color.clear
                .frame(height: 200)
                .overlay {
                    if photos.isLoadingFirstPhoto {
                        Theme.Colors.fill
                            .overlay { ProgressView() }
                            .accessibilityLabel("Loading photo")
                    } else {
                        if photos.selected == nil {
                            RecipePhoto(data: nil, title: draft.title)
                        } else {
                            RecipePhoto(data: photos.selected?.preview, title: draft.title, photoLabel: "Recipe photo")
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(draft.title)
                    .font(Theme.Fonts.rowTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("^[\(draft.ingredients.count) ingredient](inflect: true) · ^[\(draft.steps.count) step](inflect: true)")
                    .font(Theme.Fonts.meta)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if photos.photos.count > 1 {
                PhotoChoiceStrip(
                    choices: photos.photos.map { photo in
                        PhotoChoiceStrip<URL>.Choice(id: photo.url, image: Image(uiImage: UIImage(data: photo.preview) ?? UIImage()))
                    },
                    selection: $photos.selectedURL
                )
            } else if !photos.isLoading, photos.photos.isEmpty {
                Text("No photo found on the page. You can add one after saving.")
                    .font(Theme.Fonts.meta)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .motion(Motion.smooth, value: photos.selectedURL)
        .motion(Motion.smooth, value: photos.photos.count)
    }
}
