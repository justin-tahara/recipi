import RecipiDesign
import RecipiKit
import SwiftUI

/// The recipe's tags as pills you can tap to remove, a field to add one,
/// and suggestions from tags already used on other recipes.
struct TagEditor: View {
    @Binding var draft: RecipeEditDraft
    /// Names of tags already in the library.
    let existing: [String]
    /// Colors of existing tags by lowercased name, for ones a person
    /// recolored. Other tags use the color their name hashes to.
    var colors: [String: TagColor] = [:]
    var focus: FocusState<EditorField?>.Binding

    @State private var newTag = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let suggestions = draft.tagSuggestions(for: newTag, from: existing)
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if !draft.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(draft.tags, id: \.self) { name in
                        removablePill(name)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
            }

            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "plus")
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .accessibilityHidden(true)
                TextField("Add a tag", text: $newTag)
                    .focused(focus, equals: .newTag)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit {
                        add(newTag)
                        focus.wrappedValue = .newTag
                    }
                    .accessibilityHint("Type a tag and press Return. Separate several with commas.")
            }

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(newTag.isEmpty ? "Your tags" : "Matching tags")
                        .font(Theme.Fonts.eyebrow)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .accessibilityAddTraits(.isHeader)
                    FlowLayout(spacing: 6) {
                        ForEach(suggestions, id: \.self) { name in
                            Button {
                                add(name)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus")
                                        .font(.caption2.weight(.bold))
                                        .accessibilityHidden(true)
                                    Text(name)
                                }
                                .font(Theme.Fonts.label)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.pressable)
                            .accessibilityLabel("Add tag \(name)")
                        }
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xxs)
        .onChange(of: newTag) { _, value in
            // A comma finishes a tag, so "dinner, quick" adds two.
            guard value.contains(",") else { return }
            var pieces = value.components(separatedBy: ",")
            let unfinished = pieces.removeLast()
            for piece in pieces { add(piece) }
            newTag = unfinished.trimmingCharacters(in: .whitespaces)
        }
        .sensoryFeedback(.selection, trigger: draft.tags)
    }

    private func removablePill(_ name: String) -> some View {
        let color = colors[name.lowercased()] ?? TagColor.forName(name)
        return Button {
            withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                draft.removeTag(name)
            }
        } label: {
            HStack(spacing: 4) {
                Text(name)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .opacity(0.7)
                    .accessibilityHidden(true)
            }
            .font(Theme.Fonts.label)
            .foregroundStyle(color.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.background, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            // The pill stays small; the button takes touches 44 pt tall.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Remove tag \(name)")
    }

    private func add(_ name: String) {
        withMotion(Motion.snappy, reduceMotion: reduceMotion) {
            _ = draft.addTag(name, existing: existing)
        }
        newTag = ""
    }
}
