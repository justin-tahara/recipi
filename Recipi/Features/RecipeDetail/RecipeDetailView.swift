import RecipiKit
import SwiftData
import SwiftUI

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var modelContext

    /// Servings currently shown. 0 until the view appears, and when the
    /// recipe doesn't say how many it serves.
    @State private var servings = 0
    @State private var isCooking = false
    @State private var isEditing = false
    @State private var showsGroceryConfirmation = false

    var body: some View {
        List {
            if recipe.photoData != nil {
                Section {
                    RecipePhoto(data: recipe.photoData)
                        .frame(height: 240)
                        .clipped()
                        .listRowInsets(EdgeInsets())
                }
            }

            if !recipe.summary.isEmpty || hasTimes {
                Section {
                    if !recipe.summary.isEmpty {
                        Text(recipe.summary)
                    }
                    if let prepTime = recipe.prepTime {
                        LabeledContent("Prep", value: RecipeFormat.duration(prepTime))
                    }
                    if let cookTime = recipe.cookTime {
                        LabeledContent("Cook", value: RecipeFormat.duration(cookTime))
                    }
                    if let totalTime = recipe.totalTime {
                        LabeledContent("Total", value: RecipeFormat.duration(totalTime))
                    }
                }
            }

            Section("Ingredients") {
                if recipe.servings != nil {
                    Stepper("Serves \(servings)", value: $servings, in: 1...99)
                }
                ForEach(recipe.sortedIngredients) { ingredient in
                    Text(ingredient.parsed.scaled(by: scale))
                }
            }

            Section("Method") {
                ForEach(Array(recipe.sortedSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .monospacedDigit()
                        Text(step.text)
                    }
                }
            }

            if !recipe.notes.isEmpty {
                Section("Notes") {
                    Text(recipe.notes)
                }
            }

            if let sourceURL = recipe.sourceURL {
                Section {
                    Link("View original recipe", destination: sourceURL)
                }
            }
        }
        .navigationTitle(recipe.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") { isEditing = true }
                    Button("Add to grocery list", systemImage: "cart.badge.plus", action: addToGroceryList)
                    Button(recipe.isFavorite ? "Unfavorite" : "Favorite", systemImage: recipe.isFavorite ? "heart.slash" : "heart") {
                        recipe.isFavorite.toggle()
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isCooking = true
            } label: {
                Label("Start cooking", systemImage: "frying.pan")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .disabled(recipe.sortedSteps.isEmpty)
        }
        .fullScreenCover(isPresented: $isCooking) {
            CookingModeView(recipe: recipe, scale: scale)
        }
        .sheet(isPresented: $isEditing) {
            RecipeEditorView(recipe: recipe)
        }
        .alert("Added to your grocery list", isPresented: $showsGroceryConfirmation) {
            Button("OK", role: .cancel) {}
        }
        .onAppear {
            if servings == 0 {
                servings = recipe.servings ?? 0
            }
        }
    }

    private var hasTimes: Bool {
        recipe.prepTime != nil || recipe.cookTime != nil || recipe.totalTime != nil
    }

    private var scale: Double {
        guard let base = recipe.servings, base > 0, servings > 0 else { return 1 }
        return Double(servings) / Double(base)
    }

    private func addToGroceryList() {
        for ingredient in recipe.sortedIngredients {
            modelContext.insert(GroceryItem(text: ingredient.parsed.scaled(by: scale), recipeTitle: recipe.title))
        }
        showsGroceryConfirmation = true
    }
}
