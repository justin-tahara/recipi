import RecipiKit
import SwiftData
import SwiftUI

struct ImportRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://", text: $urlText)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await importRecipe() } }
                } footer: {
                    Text("Paste a link to a recipe. You can also share a page to recipi straight from Safari.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Import recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isImporting {
                        ProgressView()
                    } else {
                        Button("Import") { Task { await importRecipe() } }
                            .disabled(url == nil)
                    }
                }
            }
        }
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
