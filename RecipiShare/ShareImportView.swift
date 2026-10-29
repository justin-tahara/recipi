import RecipiDesign
import RecipiKit
import SwiftUI
import UIKit

struct ShareImportView: View {
    let model: ShareImportModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                switch model.state {
                case .importing:
                    ProgressView()
                        .controlSize(.large)
                        .frame(width: 64, height: 64)
                    Text("Reading recipe…")
                        .font(Theme.Fonts.meta)
                        .foregroundStyle(Theme.Colors.textSecondary)
                case .preview(let draft):
                    if let photoChoice = model.photoChoice {
                        SharePreview(draft: draft, photos: photoChoice)
                    }
                    Button {
                        Task { await model.save() }
                    } label: {
                        Text("Save recipe")
                    }
                    .buttonStyle(.recipiPrimary)
                    .disabled(!model.canSave)
                case .saving:
                    ProgressView()
                        .controlSize(.large)
                        .frame(width: 64, height: 64)
                    Text("Saving recipe…")
                        .font(Theme.Fonts.meta)
                        .foregroundStyle(Theme.Colors.textSecondary)
                case .saved(let title):
                    statusIcon("checkmark", color: .green)
                    Text("Saved \(title)")
                        .font(Theme.Fonts.rowTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                case .alreadySaved(let title, _):
                    statusIcon("checkmark", color: .blue)
                    Text("Already in recipi")
                        .font(Theme.Fonts.rowTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("“\(title)” is already in your library.")
                        .font(Theme.Fonts.meta)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Done") { model.close() }
                        .buttonStyle(.recipiPrimary)
                    Button("Save another copy") {
                        Task { await model.saveAnotherCopy() }
                    }
                    .buttonStyle(.recipiSecondary)
                case .failed(let message):
                    statusIcon("exclamationmark.triangle.fill", color: .orange)
                    Text(message)
                        .font(Theme.Fonts.meta)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
            .id(phase)
            .motion(Motion.bouncy, value: phase)
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)
            .navigationTitle("recipi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { model.close() }
                }
            }
        }
        .tint(Theme.Colors.accent)
        .sensoryFeedback(.success, trigger: phase) { _, newValue in newValue == 1 }
    }

    /// 0 while importing or saving, 1 once saved, 2 on failure, 3 while the
    /// recipe is shown before saving, 4 when it was already saved. Drives
    /// the animation between states.
    private var phase: Int {
        switch model.state {
        case .importing, .saving: 0
        case .saved: 1
        case .failed: 2
        case .preview: 3
        case .alreadySaved: 4
        }
    }

    private func statusIcon(_ symbol: String, color: TagColor) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(color.foreground)
            .frame(width: 64, height: 64)
            .background(color.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .bounceEffect(value: phase)
            .accessibilityHidden(true)
    }
}

/// The shared recipe before it's saved: its photo, a choice of photos when
/// the page offers several, and what was found.
private struct SharePreview: View {
    let draft: RecipeDraft
    @Bindable var photos: ImportPhotoChoice

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Color.clear
                .frame(height: 180)
                .overlay { photo }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(draft.title)
                    .font(Theme.Fonts.rowTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
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
                Text("No photo found on the page. You can add one later.")
                    .font(Theme.Fonts.meta)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .motion(Motion.smooth, value: photos.selectedURL)
        .motion(Motion.smooth, value: photos.photos.count)
    }

    @ViewBuilder
    private var photo: some View {
        if photos.isLoadingFirstPhoto {
            Theme.Colors.fill
                .overlay { ProgressView() }
                .accessibilityLabel("Loading photo")
        } else if let preview = photos.selected?.preview, let image = UIImage(data: preview) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityLabel("Recipe photo")
        } else {
            // The same soft tile the library shows for a recipe without one.
            let color = TagColor.forName(draft.title)
            Rectangle()
                .fill(color.background)
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(color.foreground)
                }
                .accessibilityLabel("No photo")
        }
    }
}
