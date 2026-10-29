import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

struct ImportRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Image(systemName: "link")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(TagColor.blue.foreground)
                        .frame(width: 56, height: 56)
                        .background(TagColor.blue.background, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Import from a link")
                            .font(Theme.Fonts.sectionTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
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

                    Button {
                        Task { await importRecipe() }
                    } label: {
                        if isImporting {
                            ProgressView()
                                .tint(Theme.Colors.onAccent)
                        } else {
                            Text("Import recipe")
                        }
                    }
                    .buttonStyle(.recipiPrimary)
                    .disabled(url == nil || isImporting)
                }
                .padding(Theme.Spacing.page)
                .motion(Motion.snappy, value: errorMessage)
            }
            .background(Theme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isFieldFocused = true }
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
                .onSubmit { Task { await importRecipe() } }
            if !urlText.isEmpty {
                Button {
                    urlText = ""
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
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

    private var url: URL? {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    private func importRecipe() async {
        guard let url, !isImporting else { return }
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            try await RecipeImporter().saveRecipe(from: url, into: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
