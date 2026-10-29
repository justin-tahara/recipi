import PhotosUI
import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

/// Add a recipe by hand, or fix anything about one that was imported. The
/// screen edits a copy (`RecipeEditDraft`) that's only written back on
/// Save, so Cancel leaves the recipe exactly as it was.
///
/// Ingredients and steps are lists with one row per line. Section headings
/// are rows of their own, rows can be dragged to reorder, and an ingredient
/// shows its amount, unit and name as separate fields while it's edited.
struct RecipeEditorView: View {
    let recipe: Recipe
    /// A new recipe is a placeholder until it's saved: Cancel deletes it,
    /// and so does saving it with nothing in it.
    let isNew: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Tag.name) private var libraryTags: [Tag]

    @State private var draft: RecipeEditDraft
    /// The draft as it was loaded, to tell whether anything changed.
    @State private var original: RecipeEditDraft
    @State private var photoItem: PhotosPickerItem?
    @State private var editMode: EditMode = .inactive
    @State private var isConfirmingDiscard = false
    /// The ingredient whose amount, unit and name fields are showing.
    @State private var expandedIngredient: UUID?
    @FocusState private var focus: EditorField?

    init(recipe: Recipe, isNew: Bool = false) {
        self.recipe = recipe
        self.isNew = isNew
        let draft = RecipeEditDraft(recipe)
        _draft = State(initialValue: draft)
        _original = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            List {
                titleSection
                photoSection
                detailsSection
                ingredientsSection
                stepsSection
                tagsSection
                notesSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.surface)
            .scrollDismissesKeyboard(.interactively)
            .environment(\.editMode, $editMode)
            .motion(Motion.smooth, value: draft.photoData != nil)
            .motion(Motion.snappy, value: expandedIngredient)
            .navigationTitle(isNew ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .interactiveDismissDisabled()
            .confirmationDialog(
                isNew ? "Discard this recipe?" : "Discard your changes?",
                isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button(isNew ? "Discard recipe" : "Discard changes", role: .destructive, action: discard)
                Button("Keep editing", role: .cancel) {}
            }
            .onChange(of: photoItem) {
                Task { await loadPhoto() }
            }
            .onChange(of: focus) { _, newValue in
                updateExpandedIngredient(for: newValue)
            }
            .onAppear {
                if isNew { focusSoon(.title) }
            }
        }
        .tint(Theme.Colors.accent)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: cancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .fontWeight(.semibold)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button {
                focus = nil
            } label: {
                Label("Hide keyboard", systemImage: "keyboard.chevron.compact.down")
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section {
            TextField("Recipe title", text: $draft.title, axis: .vertical)
                .font(Theme.Fonts.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .focused($focus, equals: .title)
            TextField("Add a short description", text: $draft.summary, axis: .vertical)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1...8)
                .accessibilityLabel("Description")
        }
        .listRowBackground(Theme.Colors.elevated)
    }

    private var photoSection: some View {
        Section("Photo") {
            if draft.photoData != nil {
                RecipePhoto(data: draft.photoData, title: draft.title)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            // PhotosPicker's label closure is Sendable, so read the
            // main-actor state here rather than inside it.
            let photoLabel = draft.photoData == nil ? "Add photo" : "Change photo"
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photoLabel, systemImage: "photo")
            }
            if draft.photoData != nil {
                Button("Remove photo", systemImage: "trash", role: .destructive) {
                    photoItem = nil
                    withMotion(Motion.smooth, reduceMotion: reduceMotion) {
                        draft.photoData = nil
                    }
                }
            }
        }
        .listRowBackground(Theme.Colors.elevated)
    }

    private var detailsSection: some View {
        Section {
            EditorPropertyRow("Source", symbol: "link") {
                TextField("https://", text: $draft.sourceURLText)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Source link")
            }
            EditorPropertyRow("Author", symbol: "person") {
                TextField("Who wrote it", text: $draft.author)
                    .accessibilityLabel("Author")
            }
            EditorPropertyRow("Servings", symbol: "person.2") {
                TextField("How many", text: servingsText)
                    .keyboardType(.numberPad)
                    .accessibilityLabel("Servings")
            }
            EditorPropertyRow("Makes", symbol: "square.stack") {
                TextField("e.g. 24 cookies", text: $draft.yieldText)
                    .accessibilityLabel("Makes")
            }
            EditorPropertyRow("Prep", symbol: "timer") {
                DurationField(label: "Prep time", value: $draft.prepTime)
            }
            EditorPropertyRow("Cook", symbol: "flame") {
                DurationField(label: "Cook time", value: $draft.cookTime)
            }
            EditorPropertyRow("Total", symbol: "clock") {
                DurationField(label: "Total time", value: $draft.totalTime)
            }
            Toggle(isOn: $draft.isFavorite) {
                Label {
                    Text("Favorite")
                        .foregroundStyle(Theme.Colors.textPrimary)
                } icon: {
                    Image(systemName: draft.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(draft.isFavorite ? TagColor.pink.foreground : Theme.Colors.textSecondary)
                        .bounceEffect(value: draft.isFavorite)
                }
            }
            .tint(TagColor.pink.foreground)
            .sensoryFeedback(.selection, trigger: draft.isFavorite)
        } header: {
            Text("Details")
        } footer: {
            if draft.isSourceURLValid {
                Text("Amounts are written for this many servings; the recipe scales from it.")
            } else {
                Text("That doesn't look like a web address, so the current link is kept until it is one.")
                    .foregroundStyle(TagColor.red.foreground)
            }
        }
        .listRowBackground(Theme.Colors.elevated)
    }

    private var ingredientsSection: some View {
        let numbers = Self.itemNumbers(in: draft.ingredients)
        return Section {
            ForEach(draft.ingredients) { row in
                rowEditor(row, in: .ingredients, number: numbers[row.id] ?? 0)
            }
            .onMove { moveRows(in: .ingredients, from: $0, to: $1) }
            .onDelete { deleteRows(in: .ingredients, at: $0) }
            addRowButtons(for: .ingredients)
        } header: {
            listHeader("Ingredients")
        } footer: {
            Text("Press Return for a new line, or paste several lines at once. Swipe right on a line to make it a section heading.")
        }
        .listRowBackground(Theme.Colors.elevated)
    }

    private var stepsSection: some View {
        let numbers = Self.itemNumbers(in: draft.steps)
        return Section {
            ForEach(draft.steps) { row in
                rowEditor(row, in: .steps, number: numbers[row.id] ?? 0)
            }
            .onMove { moveRows(in: .steps, from: $0, to: $1) }
            .onDelete { deleteRows(in: .steps, at: $0) }
            addRowButtons(for: .steps)
        } header: {
            listHeader("Method")
        }
        .listRowBackground(Theme.Colors.elevated)
    }

    private var tagsSection: some View {
        Section("Tags") {
            TagEditor(draft: $draft, existing: libraryTagNames, focus: $focus)
        }
        .listRowBackground(Theme.Colors.elevated)
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Tips, swaps, what you'd change next time", text: $draft.notes, axis: .vertical)
                .lineLimit(3...12)
                .accessibilityLabel("Notes")
        }
        .listRowBackground(Theme.Colors.elevated)
    }

    // MARK: - Rows

    /// Ingredients or method: the two lists of rows in the draft.
    private enum RowList {
        case ingredients, steps
    }

    @ViewBuilder
    private func rowEditor(_ row: RecipeEditDraft.Row, in list: RowList, number: Int) -> some View {
        let text = textBinding(for: row.id, in: list)
        let actions = rowActions(for: row, in: list)
        Group {
            switch (row.kind, list) {
            case (.heading, _):
                HeadingRowEditor(id: row.id, text: text, actions: actions, focus: $focus)
            case (.item, .ingredients):
                IngredientRowEditor(
                    id: row.id,
                    number: number,
                    text: text,
                    isExpanded: expandedIngredient == row.id,
                    actions: actions,
                    focus: $focus
                )
            case (.item, .steps):
                StepRowEditor(id: row.id, number: number, text: text, actions: actions, focus: $focus)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(actions.toggleKindTitle, systemImage: row.kind == .heading ? "text.alignleft" : "textformat") {
                actions.toggleKind()
            }
            .tint(TagColor.blue.foreground)
        }
        .onChange(of: row.text) { _, newValue in
            // Return, or a paste of several lines, makes new rows.
            guard newValue.contains(where: \.isNewline) else { return }
            var next: UUID?
            withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                updateRows(list) { next = $0.splitLines(at: row.id) }
            }
            if let next { focusSoon(.row(next)) }
        }
    }

    private func rowActions(for row: RecipeEditDraft.Row, in list: RowList) -> RowActions {
        let siblings = rows(list)
        let index = siblings.firstIndex { $0.id == row.id } ?? 0
        let itemName = list == .ingredients ? "ingredient" : "step"
        let moveUp: (() -> Void)? = index > 0 ? { moveRow(row.id, in: list, by: -1) } : nil
        let moveDown: (() -> Void)? = index < siblings.count - 1 ? { moveRow(row.id, in: list, by: 1) } : nil
        return RowActions(
            toggleKindTitle: row.kind == .heading ? "Make \(itemName)" : "Make heading",
            toggleKind: {
                withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                    updateRows(list) { $0.toggleKind(of: row.id) }
                }
            },
            delete: {
                withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                    updateRows(list) { $0.removeRow(row.id) }
                }
            },
            moveUp: moveUp,
            moveDown: moveDown
        )
    }

    private func addRowButtons(for list: RowList) -> some View {
        let itemTitle = list == .ingredients ? "Add ingredient" : "Add step"
        let buttons = Group {
            Button {
                addRow(.item, to: list)
            } label: {
                Label(itemTitle, systemImage: "plus")
            }
            Button {
                addRow(.heading, to: list)
            } label: {
                Label("Add section", systemImage: "textformat")
            }
        }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.lg) { buttons }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) { buttons }
        }
        // Borderless, so each button in the row takes its own taps.
        .buttonStyle(.borderless)
        .font(Theme.Fonts.meta)
        .foregroundStyle(Theme.Colors.textSecondary)
    }

    private func listHeader(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button(editMode.isEditing ? "Done" : "Reorder") {
                focus = nil
                withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                    editMode = editMode.isEditing ? .inactive : .active
                }
            }
            .font(Theme.Fonts.label)
            .textCase(nil)
            .accessibilityLabel(editMode.isEditing ? "Done reordering" : "Reorder \(title.lowercased())")
        }
    }

    // MARK: - Draft changes

    private func rows(_ list: RowList) -> [RecipeEditDraft.Row] {
        switch list {
        case .ingredients: draft.ingredients
        case .steps: draft.steps
        }
    }

    private func updateRows(_ list: RowList, _ change: (inout [RecipeEditDraft.Row]) -> Void) {
        switch list {
        case .ingredients: change(&draft.ingredients)
        case .steps: change(&draft.steps)
        }
    }

    /// Looks the row up by id each time, so a field never writes into the
    /// wrong row after rows move or are deleted.
    private func textBinding(for id: UUID, in list: RowList) -> Binding<String> {
        Binding {
            rows(list).first { $0.id == id }?.text ?? ""
        } set: { newValue in
            updateRows(list) { rows in
                if let index = rows.firstIndex(where: { $0.id == id }) {
                    rows[index].text = newValue
                }
            }
        }
    }

    private var servingsText: Binding<String> {
        Binding {
            draft.servings.map { String($0) } ?? ""
        } set: { newValue in
            let digits = newValue.filter(\.isASCII).filter(\.isNumber)
            draft.servings = Int(String(digits.prefix(3)))
        }
    }

    private func addRow(_ kind: RecipeEditDraft.Row.Kind, to list: RowList) {
        var newID: UUID?
        withMotion(Motion.snappy, reduceMotion: reduceMotion) {
            updateRows(list) { newID = $0.insertRow(kind) }
        }
        if let newID { focusSoon(.row(newID)) }
    }

    private func moveRows(in list: RowList, from source: IndexSet, to destination: Int) {
        updateRows(list) { $0.moveRows(fromOffsets: source, toOffset: destination) }
    }

    private func moveRow(_ id: UUID, in list: RowList, by offset: Int) {
        withMotion(Motion.snappy, reduceMotion: reduceMotion) {
            updateRows(list) { $0.moveRow(id, by: offset) }
        }
    }

    private func deleteRows(in list: RowList, at offsets: IndexSet) {
        updateRows(list) { $0.remove(atOffsets: offsets) }
    }

    private func updateExpandedIngredient(for field: EditorField?) {
        // Keep the last row open while the keyboard is down, so moving
        // between its fields never collapses it under the finger.
        guard let field else { return }
        if let id = field.rowID, draft.ingredients.contains(where: { $0.id == id && $0.kind == .item }) {
            expandedIngredient = id
        } else {
            expandedIngredient = nil
        }
    }

    /// Moves the cursor once a just-added row is on screen.
    private func focusSoon(_ field: EditorField) {
        Task {
            try? await Task.sleep(for: .milliseconds(60))
            focus = field
        }
    }

    // MARK: - Save and cancel

    private func cancel() {
        let hasChanges = isNew ? !draft.isBlank : draft != original
        if hasChanges {
            isConfirmingDiscard = true
        } else {
            discard()
        }
    }

    private func discard() {
        if isNew {
            modelContext.delete(recipe)
        }
        dismiss()
    }

    private func save() {
        focus = nil
        if isNew && draft.isBlank {
            modelContext.delete(recipe)
        } else if isNew || draft != original {
            draft.apply(to: recipe, in: modelContext)
        }
        dismiss()
    }

    private func loadPhoto() async {
        guard let photoItem, let data = try? await photoItem.loadTransferable(type: Data.self) else { return }
        withMotion(Motion.smooth, reduceMotion: reduceMotion) {
            draft.photoData = data
        }
    }

    // MARK: - Helpers

    /// Tags used on at least one recipe, for suggestions.
    private var libraryTagNames: [String] {
        libraryTags.filter { !($0.recipes ?? []).isEmpty }.map(\.name)
    }

    /// Numbers items 1, 2, 3… skipping headings, like the recipe page.
    private static func itemNumbers(in rows: [RecipeEditDraft.Row]) -> [UUID: Int] {
        var numbers: [UUID: Int] = [:]
        var count = 0
        for row in rows where row.kind == .item {
            count += 1
            numbers[row.id] = count
        }
        return numbers
    }
}
