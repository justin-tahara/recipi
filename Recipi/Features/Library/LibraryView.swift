import RecipiKit
import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.title) private var recipes: [Recipe]

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var isShowingImport = false
    @State private var newRecipe: Recipe?

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "No recipes yet",
                        systemImage: "fork.knife",
                        description: Text("Import one from a link, share a page from Safari, or add your own.")
                    )
                } else {
                    List {
                        ForEach(filteredRecipes) { recipe in
                            NavigationLink(value: recipe) {
                                RecipeRow(recipe: recipe)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Recipes")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .searchable(text: $searchText, prompt: "Search recipes or ingredients")
            .toolbar { toolbar }
            .sheet(isPresented: $isShowingImport) {
                ImportRecipeView()
            }
            .sheet(item: $newRecipe) { recipe in
                RecipeEditorView(recipe: recipe, isNew: true)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Import from link", systemImage: "link") { isShowingImport = true }
                Button("Add manually", systemImage: "square.and.pencil", action: addManually)
            } label: {
                Label("Add recipe", systemImage: "plus")
            }
        }
        if !allTags.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Tag", selection: $selectedTag) {
                        Text("All recipes").tag(String?.none)
                        ForEach(allTags, id: \.self) { tag in
                            Text(tag).tag(String?.some(tag))
                        }
                    }
                } label: {
                    Label("Filter by tag", systemImage: selectedTag == nil
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
    }

    private var allTags: [String] {
        Set(recipes.flatMap { $0.sortedTags.map(\.name) }).sorted()
    }

    private var filteredRecipes: [Recipe] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return recipes.filter { recipe in
            if let selectedTag, !recipe.sortedTags.contains(where: { $0.name == selectedTag }) {
                return false
            }
            guard !query.isEmpty else { return true }
            return recipe.title.localizedCaseInsensitiveContains(query)
                || recipe.sortedIngredients.contains { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    private func addManually() {
        let recipe = Recipe()
        modelContext.insert(recipe)
        newRecipe = recipe
    }

    private func delete(at offsets: IndexSet) {
        let visible = filteredRecipes
        for index in offsets {
            modelContext.delete(visible[index])
        }
    }
}

private struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            RecipePhoto(data: recipe.photoData)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title.isEmpty ? "Untitled recipe" : recipe.title)
                    .font(.headline)
                    .lineLimit(2)
                if let totalTime = recipe.totalTime {
                    Text(RecipeFormat.duration(totalTime))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
