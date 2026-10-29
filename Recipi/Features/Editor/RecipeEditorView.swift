import PhotosUI
import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

/// Add or edit a recipe by hand. Ingredients and steps are edited as one
/// item per line, which is quick to type and easy to paste into.
struct RecipeEditorView: View {
    @Bindable var recipe: Recipe
    /// A new recipe that ends up empty is deleted instead of saved.
    var isNew = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var ingredientsText = ""
    @State private var stepsText = ""
    @State private var tagsText = ""
    @State private var servingsText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        TextField("Title", text: $recipe.title)
                            .font(Theme.Fonts.sectionTitle)
                        TextField("Description", text: $recipe.summary, axis: .vertical)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Section("Photo") {
                        if recipe.photoData != nil {
                            RecipePhoto(data: recipe.photoData, title: recipe.title)
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                                .transition(.opacity)
                                .accessibilityHidden(true)
                        }
                        // PhotosPicker's label closure is Sendable, so read the
                        // main-actor model here rather than inside it.
                        let photoLabel = recipe.photoData == nil ? "Add photo" : "Change photo"
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(photoLabel, systemImage: "photo")
                        }
                    }

                    Section("Servings") {
                        TextField("Serves", text: $servingsText)
                            .keyboardType(.numberPad)
                    }

                    Section {
                        TextEditor(text: $ingredientsText)
                            .frame(minHeight: 140)
                    } header: {
                        Text("Ingredients")
                    } footer: {
                        Text("One per line, e.g. \"1 1/2 cups flour\".")
                    }

                    Section {
                        TextEditor(text: $stepsText)
                            .frame(minHeight: 180)
                    } header: {
                        Text("Method")
                    } footer: {
                        Text("One step per line.")
                    }

                    Section {
                        TextField("Dinner, vegetarian, quick", text: $tagsText)
                    } header: {
                        Text("Tags")
                    } footer: {
                        Text("Separate tags with commas.")
                    }

                    Section("Notes") {
                        TextField("Notes", text: $recipe.notes, axis: .vertical)
                    }
                }
                .listRowBackground(Theme.Colors.elevated)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.surface)
            .motion(Motion.smooth, value: recipe.photoData != nil)
            .navigationTitle(isNew ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled()
            .onAppear(perform: load)
            .onChange(of: photoItem) {
                Task { await loadPhoto() }
            }
        }
        .tint(Theme.Colors.accent)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        ingredientsText = recipe.sortedIngredients.map(\.text).joined(separator: "\n")
        stepsText = recipe.sortedSteps.map(\.text).joined(separator: "\n")
        tagsText = recipe.sortedTags.map(\.name).joined(separator: ", ")
        servingsText = recipe.servings.map { String($0) } ?? ""
    }

    private func save() {
        let ingredientLines = ingredientsText.components(separatedBy: .newlines)
        let stepLines = stepsText.components(separatedBy: .newlines)

        recipe.setIngredients(ingredientLines, in: modelContext)
        recipe.setSteps(stepLines, in: modelContext)
        recipe.servings = Int(servingsText.trimmingCharacters(in: .whitespaces))
        recipe.tags = tagsText
            .split(separator: ",")
            .compactMap { Tag.findOrCreate(named: String($0), in: modelContext) }
        recipe.updatedAt = .now

        let isEmpty = recipe.title.trimmingCharacters(in: .whitespaces).isEmpty
            && (recipe.ingredients ?? []).isEmpty
            && (recipe.steps ?? []).isEmpty
        if isNew && isEmpty {
            modelContext.delete(recipe)
        }
    }

    private func loadPhoto() async {
        guard let photoItem, let data = try? await photoItem.loadTransferable(type: Data.self) else { return }
        recipe.photoData = data
    }
}
