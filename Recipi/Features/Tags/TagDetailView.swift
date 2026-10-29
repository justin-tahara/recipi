import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

/// One tag: rename it (a name another tag already has merges the two),
/// pick its color and kind, or delete it.
struct TagDetailView: View {
    let tag: Tag

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allTags: [Tag]

    @State private var name: String
    @State private var isConfirmingMerge = false
    @State private var isConfirmingDelete = false
    /// Set just before the tag is merged away or deleted, so the screen
    /// stops reading it while it closes.
    @State private var isGone = false
    @FocusState private var isNameFocused: Bool

    init(tag: Tag) {
        self.tag = tag
        _name = State(initialValue: tag.name)
    }

    var body: some View {
        if isGone {
            Theme.Colors.surface
        } else {
            content
        }
    }

    private var content: some View {
        Form {
            Group {
                nameSection
                colorSection
                kindSection
                deleteSection
            }
            .listRowBackground(Theme.Colors.elevated)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.surface)
        .navigationTitle(tag.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!canSave)
            }
        }
        .confirmationDialog(
            "Merge into “\(mergeTarget?.name ?? trimmedName)”?",
            isPresented: $isConfirmingMerge,
            titleVisibility: .visible
        ) {
            Button("Merge Tags") { merge() }
        } message: {
            Text("Recipes tagged “\(tag.name)” get “\(mergeTarget?.name ?? trimmedName)” instead, and “\(tag.name)” is removed.")
        }
        .confirmationDialog("Delete “\(tag.name)”?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Tag", role: .destructive, action: delete)
        } message: {
            Text(Self.deleteMessage(for: tag))
        }
        .motion(Motion.snappy, value: mergeTarget?.persistentModelID)
    }

    // MARK: Name

    private var nameSection: some View {
        Section {
            TextField("Name", text: $name)
                .focused($isNameFocused)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit { if canSave { save() } }
        } header: {
            Text("Name")
        } footer: {
            if let mergeTarget {
                Text("“\(mergeTarget.name)” already exists. Saving merges this tag into it.")
            } else {
                Text(usageText)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedName != tag.name
    }

    /// Another tag that already has the typed name.
    private var mergeTarget: Tag? {
        guard !trimmedName.isEmpty else { return nil }
        return allTags.first { other in
            other.persistentModelID != tag.persistentModelID
                && other.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private var usageText: String {
        let count = tag.recipes?.count ?? 0
        return count == 1 ? "On 1 recipe." : "On \(count) recipes."
    }

    private func save() {
        guard canSave else { return }
        if mergeTarget != nil {
            isConfirmingMerge = true
            return
        }
        tag.rename(to: trimmedName, in: modelContext)
        try? modelContext.save()
        name = tag.name
        isNameFocused = false
    }

    private func merge() {
        guard let mergeTarget else { return }
        isGone = true
        tag.merge(into: mergeTarget, in: modelContext)
        try? modelContext.save()
        dismiss()
    }

    // MARK: Color

    private var colorSection: some View {
        Section {
            FlowLayout(spacing: Theme.Spacing.xs) {
                swatch(nil)
                ForEach(TagColor.tagChoices, id: \.storageName) { color in
                    swatch(color)
                }
            }
            .padding(.vertical, Theme.Spacing.xxs)
        } header: {
            Text("Color")
        } footer: {
            Text("Automatic gives each tag a color from its name.")
        }
    }

    private func swatch(_ color: TagColor?) -> some View {
        let isSelected = TagColor(storageName: tag.colorOverride) == color
        let shown = color ?? .forName(tag.name)
        return Button {
            withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                tag.colorOverride = color?.storageName
            }
            try? modelContext.save()
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(color?.displayName ?? "Automatic")
            }
            .font(Theme.Fonts.label)
            .foregroundStyle(shown.foreground)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .background(shown.background, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .strokeBorder(isSelected ? shown.foreground : .clear, lineWidth: 1)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(color?.displayName ?? "Automatic color")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Kind

    private var kindSection: some View {
        Section {
            Picker("Kind", selection: kindBinding) {
                Text("None").tag(TagKind?.none)
                ForEach(TagKind.allCases) { kind in
                    Text(kind.title).tag(Optional(kind))
                }
            }
        } footer: {
            Text("Where the tag sits among the Library's filters.")
        }
    }

    private var kindBinding: Binding<TagKind?> {
        Binding(
            get: { tag.kind },
            set: { newValue in
                tag.kind = newValue
                try? modelContext.save()
            }
        )
    }

    // MARK: Delete

    private var deleteSection: some View {
        Section {
            Button("Delete Tag", role: .destructive) { isConfirmingDelete = true }
                .foregroundStyle(TagColor.red.foreground)
        }
    }

    private func delete() {
        isGone = true
        tag.delete(in: modelContext)
        try? modelContext.save()
        dismiss()
    }

    static func deleteMessage(for tag: Tag) -> String {
        let count = tag.recipes?.count ?? 0
        switch count {
        case 0: return "No recipes use it."
        case 1: return "It comes off 1 recipe. The recipe stays."
        default: return "It comes off \(count) recipes. The recipes stay."
        }
    }
}
