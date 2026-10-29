import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Recipe.title) private var recipes: [Recipe]

    @State private var searchText = ""
    @State private var tagFilter = TagFilter()
    @State private var isShowingImport = false
    @State private var isShowingSettings = false
    @State private var newRecipe: Recipe?
    @State private var preferences = Preferences()
    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    // Centered, and scrolls when large text makes it taller
                    // than the screen.
                    GeometryReader { proxy in
                        ScrollView {
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
                            .frame(minHeight: proxy.size.height)
                        }
                        .scrollBounceBehavior(.basedOnSize)
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
        let tags = libraryTags
        return List {
            if !tags.isEmpty {
                TagFilterBar(tags: tags, filter: $tagFilter)
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
                Picker("Sort by", selection: $preferences.librarySort) {
                    ForEach(LibrarySort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
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

    /// Tags on at least one recipe, once each.
    private var libraryTags: [Tag] {
        var seen = Set<PersistentIdentifier>()
        return recipes.flatMap { $0.tags ?? [] }.filter { seen.insert($0.persistentModelID).inserted }
    }

    private var filteredRecipes: [Recipe] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let sort = preferences.librarySort
        return recipes.filter { recipe in
            if !tagFilter.matches(recipe.tagFacets) {
                return false
            }
            guard !query.isEmpty else { return true }
            return recipe.title.localizedCaseInsensitiveContains(query)
                || recipe.sortedIngredients.contains { $0.text.localizedCaseInsensitiveContains(query) }
        }
        .sorted { sort.areInIncreasingOrder($0.librarySortKey, $1.librarySortKey) }
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

private struct RecipeRow: View {
    let recipe: Recipe
    let zoomNamespace: Namespace.ID

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var photoSize: CGFloat = 64

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        // At the accessibility sizes the photo sits above the text, so the
        // title gets the full width.
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.md))
        layout {
            RecipePhoto(data: recipe.photoData, title: recipe.title)
                .frame(width: photoSize, height: photoSize)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .strokeBorder(Theme.Colors.divider, lineWidth: 0.5)
                }
                .zoomTransitionSource(id: recipe.persistentModelID, in: zoomNamespace)
                // The title is read right after it.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(recipe.title.isEmpty ? "Untitled recipe" : recipe.title)
                        .font(Theme.Fonts.rowTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(isLarge ? nil : 2)
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
        // The hidden NavigationLink behind the row does the opening.
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("library.recipe")
    }

    @ViewBuilder
    private var meta: some View {
        let tags = recipe.sortedTags
        if recipe.totalTime != nil || recipe.lastCookedAt != nil || !tags.isEmpty {
            // One line normally; at the accessibility sizes it wraps.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(FlowLayout(spacing: Theme.Spacing.xs))
                : AnyLayout(HStackLayout(spacing: Theme.Spacing.xs))
            layout {
                if let lastCookedAt = recipe.lastCookedAt {
                    let when = lastCookedAt.formatted(.relative(presentation: .named))
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal")
                            .accessibilityHidden(true)
                        Text(when)
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Cooked \(when)")
                }
                if let totalTime = recipe.totalTime {
                    let duration = RecipeFormat.duration(totalTime)
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .accessibilityHidden(true)
                        Text(duration)
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Total time \(duration)")
                }
                ForEach(tags.prefix(2)) { tag in
                    TagPill(tag.name, color: tag.color)
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
