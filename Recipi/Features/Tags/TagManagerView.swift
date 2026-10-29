import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

/// Every tag, grouped by kind, to rename, merge, recolor or delete. Opened
/// from Settings or from the end of the Library's filter row.
struct TagManagerView: View {
    /// True when shown in its own sheet rather than pushed from Settings.
    var showsDoneButton = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var tagToDelete: Tag?

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.tags) { tag in
                        NavigationLink {
                            TagDetailView(tag: tag)
                        } label: {
                            TagManagerRow(tag: tag)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash") { tagToDelete = tag }
                                .tint(TagColor.red.foreground)
                        }
                    }
                }
                .listRowBackground(Theme.Colors.elevated)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.surface)
        .overlay {
            if tags.isEmpty {
                EmptyStateView(
                    symbol: "tag",
                    title: "No tags yet",
                    message: "Tags you add to recipes, and the ones recipi adds when you import, show up here."
                )
            }
        }
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .confirmationDialog(
            deleteTitle,
            isPresented: Binding(get: { tagToDelete != nil }, set: { if !$0 { tagToDelete = nil } }),
            titleVisibility: .visible,
            presenting: tagToDelete
        ) { tag in
            Button("Delete Tag", role: .destructive) { delete(tag) }
        } message: { tag in
            Text(TagDetailView.deleteMessage(for: tag))
        }
        .tint(Theme.Colors.accent)
    }

    private var deleteTitle: String {
        tagToDelete.map { "Delete “\($0.name)”?" } ?? "Delete tag?"
    }

    private struct TagSection: Identifiable {
        var kind: TagKind?
        var tags: [Tag]
        var id: String { kind?.rawValue ?? "tags" }
        var title: String { kind?.title ?? "Other tags" }
    }

    private var sections: [TagSection] {
        var kinds: [TagKind?] = TagKind.allCases.map { Optional($0) }
        kinds.append(nil)
        return kinds.compactMap { kind in
            let matching = tags.filter { $0.kind == kind }
            return matching.isEmpty ? nil : TagSection(kind: kind, tags: matching)
        }
    }

    private func delete(_ tag: Tag) {
        tagToDelete = nil
        withMotion(Motion.snappy, reduceMotion: reduceMotion) {
            tag.delete(in: modelContext)
        }
        try? modelContext.save()
    }
}

private struct TagManagerRow: View {
    let tag: Tag

    var body: some View {
        let count = tag.recipes?.count ?? 0
        HStack(spacing: Theme.Spacing.sm) {
            TagPill(tag.name, color: tag.color)
            Spacer(minLength: Theme.Spacing.xs)
            Text(count == 1 ? "1 recipe" : "\(count) recipes")
                .font(Theme.Fonts.meta)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}
