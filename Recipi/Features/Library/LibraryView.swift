import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Recipe.title) private var recipes: [Recipe]

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var isShowingImport = false
    @State private var isShowingSettings = false
    @State private var newRecipe: Recipe?
    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    EmptyStateView(
                        symbol: "fork.knife",
                        title: "No recipes yet",
                        message: "Import one from a link, share a page from Safari, or add your own."
                    ) {
                        Button("Import from link", systemImage: "link") { isShowingImport = true }
                            .buttonStyle(.recipiPrimary)
                        Button("Add manually", systemImage: "square.and.pencil", action: addManually)
                            .buttonStyle(.recipiSecondary)
                    }
                } else {
                    recipeList
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle("Recipes")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
                    .zoomTransition(sourceID: recipe.persistentModelID, in: zoomNamespace, isEnabled: !reduceMotion)
            }
            .searchable(text: $searchText, prompt: "Search recipes or ingredients")
            .toolbar { toolbar }
            .sheet(isPresented: $isShowingImport) {
                ImportRecipeView()
            }
            .sheet(item: $newRecipe) { recipe in
                RecipeEditorView(recipe: recipe, isNew: true)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
    }

    private var recipeList: some View {
        let visible = filteredRecipes
        return List {
            if !allTags.isEmpty {
                TagFilterBar(tags: allTags, selection: $selectedTag)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.xxs, leading: 0, bottom: Theme.Spacing.xs, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Theme.Colors.background)
            }

            ForEach(visible) { recipe in
                ZStack {
                    // Hidden so the row has no disclosure chevron; the whole
                    // row still opens the recipe.
                    NavigationLink(value: recipe) { EmptyView() }
                        .opacity(0)
                    RecipeRow(recipe: recipe, zoomNamespace: zoomNamespace)
                }
                .listRowInsets(EdgeInsets(top: 10, leading: Theme.Spacing.page, bottom: 10, trailing: Theme.Spacing.page))
                .listRowBackground(Theme.Colors.background)
                .listRowSeparatorTint(Theme.Colors.divider)
                .swipeActions(edge: .leading) {
                    Button {
                        toggleFavorite(recipe)
                    } label: {
                        Label(recipe.isFavorite ? "Unfavorite" : "Favorite", systemImage: recipe.isFavorite ? "heart.slash" : "heart")
                    }
                    .tint(TagColor.pink.foreground)
                }
                .contextMenu {
                    Button(recipe.isFavorite ? "Unfavorite" : "Favorite", systemImage: recipe.isFavorite ? "heart.slash" : "heart") {
                        toggleFavorite(recipe)
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                            modelContext.delete(recipe)
                        }
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if visible.isEmpty {
                EmptyStateView(
                    symbol: "magnifyingglass",
                    title: "No matches",
                    message: "Try another search or tag.",
                    color: .gray
                )
                .allowsHitTesting(false)
            }
        }
        .motion(Motion.snappy, value: visible.map(\.persistentModelID))
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Import from link", systemImage: "link") { isShowingImport = true }
                Button("Add manually", systemImage: "square.and.pencil", action: addManually)
            } label: {
                Label("Add recipe", systemImage: "plus")
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

    private func toggleFavorite(_ recipe: Recipe) {
        withMotion(Motion.bouncy, reduceMotion: reduceMotion) {
            recipe.isFavorite.toggle()
        }
    }

    private func delete(at offsets: IndexSet) {
        let visible = filteredRecipes
        for index in offsets {
            modelContext.delete(visible[index])
        }
    }
}

/// "All" plus one chip per tag. The highlight slides between chips.
private struct TagFilterBar: View {
    let tags: [String]
    @Binding var selection: String?

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                chip(for: nil)
                ForEach(tags, id: \.self) { tag in
                    chip(for: tag)
                }
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.vertical, 2)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(for tag: String?) -> some View {
        let isSelected = selection == tag
        let color = tag.map(TagColor.forName) ?? .gray

        return Button {
            withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                selection = tag
            }
        } label: {
            HStack(spacing: 6) {
                if tag != nil {
                    Circle()
                        .fill(color.foreground)
                        .frame(width: 7, height: 7)
                }
                Text(tag ?? "All")
            }
            .font(Theme.Fonts.label)
            .foregroundStyle(isSelected ? (tag == nil ? Theme.Colors.textPrimary : color.foreground) : Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule()
                        .fill(color.background)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                } else {
                    Capsule()
                        .strokeBorder(Theme.Colors.border, lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(tag ?? "All recipes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RecipeRow: View {
    let recipe: Recipe
    let zoomNamespace: Namespace.ID

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            RecipePhoto(data: recipe.photoData, title: recipe.title)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .strokeBorder(Theme.Colors.divider, lineWidth: 0.5)
                }
                .zoomTransitionSource(id: recipe.persistentModelID, in: zoomNamespace)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(recipe.title.isEmpty ? "Untitled recipe" : recipe.title)
                        .font(Theme.Fonts.rowTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)
                    if recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(TagColor.pink.foreground)
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityLabel("Favorite")
                    }
                }
                meta
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("library.recipe")
    }

    @ViewBuilder
    private var meta: some View {
        let tags = recipe.sortedTags
        if recipe.totalTime != nil || !tags.isEmpty {
            HStack(spacing: Theme.Spacing.xs) {
                if let totalTime = recipe.totalTime {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                        Text(RecipeFormat.duration(totalTime))
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
                ForEach(tags.prefix(2)) { tag in
                    TagPill(tag.name)
                }
                if tags.count > 2 {
                    Text("+\(tags.count - 2)")
                        .font(Theme.Fonts.label)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
    }
}
