import RecipiDesign
import RecipiKit
import SwiftUI

/// "All", then the library's tags as chips grouped by kind (cuisine, meal,
/// diet, traits, then plain tags), each in its tag color. Any number can be
/// picked; see `TagFilter` for how they combine. Group chips like "Asian"
/// match each of their cuisines. The last button opens tag management.
struct TagFilterBar: View {
    /// Tags on at least one recipe.
    let tags: [Tag]
    @Binding var filter: TagFilter

    @State private var isShowingTagManager = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let sections = TagFilterSection.sections(for: tags.map(\.facet))
        let colors = Dictionary(
            tags.map { (TagVocabulary.normalized($0.name), $0.color) },
            uniquingKeysWith: { first, _ in first }
        )

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                allChip
                ForEach(sections) { section in
                    sectionLabel(section)
                    ForEach(section.chips) { facet in
                        chip(facet, color: colors[TagVocabulary.normalized(facet.name)] ?? .forName(facet.name))
                    }
                }
                manageButton
            }
            .padding(.horizontal, Theme.Spacing.page)
        }
        .sensoryFeedback(.selection, trigger: filter)
        .onChange(of: sections.flatMap(\.chips)) { _, available in
            // A chip whose tag was renamed or deleted can't be unpicked.
            filter.keep(only: available)
        }
        .sheet(isPresented: $isShowingTagManager) {
            NavigationStack {
                TagManagerView(showsDoneButton: true)
            }
        }
    }

    private var allChip: some View {
        let isSelected = filter.isEmpty
        return Button {
            withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                filter.clear()
            }
        } label: {
            Text("All")
                .modifier(ChipStyle(isSelected: isSelected, color: .gray, selectedText: Theme.Colors.textPrimary))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("All recipes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sectionLabel(_ section: TagFilterSection) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Rectangle()
                .fill(Theme.Colors.divider)
                .frame(width: 1, height: 18)
                .accessibilityHidden(true)
            Text(section.title)
                .font(Theme.Fonts.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.textTertiary)
                .fixedSize()
        }
        .padding(.leading, Theme.Spacing.xxs)
        .accessibilityAddTraits(.isHeader)
    }

    private func chip(_ facet: TagFacet, color: TagColor) -> some View {
        let isSelected = filter.isSelected(facet)
        return Button {
            withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                filter.toggle(facet)
            }
        } label: {
            HStack(spacing: 6) {
                if facet.isGroup {
                    // Two dots: this chip stands for several cuisines.
                    HStack(spacing: -3) {
                        Circle().fill(color.foreground.opacity(0.55))
                        Circle().fill(color.foreground)
                    }
                    .frame(width: 13, height: 7)
                    .accessibilityHidden(true)
                } else {
                    Circle()
                        .fill(color.foreground)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                }
                Text(facet.name)
                    .lineLimit(1)
            }
            .modifier(ChipStyle(isSelected: isSelected, color: color, selectedText: color.foreground))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(facet.isGroup ? "\(facet.name), all \(facet.name) cuisines" : facet.name)
        .accessibilityHint(facet.kind.map { "\($0.title) filter" } ?? "Tag filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var manageButton: some View {
        Button {
            isShowingTagManager = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .modifier(ChipStyle(isSelected: false, color: .gray, selectedText: Theme.Colors.textPrimary))
        }
        .buttonStyle(.pressable)
        .padding(.leading, Theme.Spacing.xxs)
        .accessibilityLabel("Manage tags")
    }
}

/// A chip's shape: filled in its tag color when picked, outlined otherwise.
/// The capsule is drawn at the text's size; the chip takes touches across a
/// full 44 pt height.
private struct ChipStyle: ViewModifier {
    let isSelected: Bool
    let color: TagColor
    let selectedText: Color

    func body(content: Content) -> some View {
        content
            .font(Theme.Fonts.label)
            .foregroundStyle(isSelected ? selectedText : Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule().fill(color.background)
                } else {
                    Capsule().strokeBorder(Theme.Colors.border, lineWidth: 0.5)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}
