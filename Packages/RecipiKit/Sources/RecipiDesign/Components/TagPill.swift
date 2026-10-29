import SwiftUI

/// A tag as Notion draws one: a small rounded label in the tag's color.
/// VoiceOver reads it as "Tag, Vegetarian" unless given another label,
/// e.g. when the pill shows a recipe's name rather than a tag.
public struct TagPill: View {
    let name: String
    let color: TagColor
    let accessibilityText: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(_ name: String, color: TagColor? = nil, accessibilityLabel: String? = nil) {
        self.name = name
        self.color = color ?? .forName(name)
        self.accessibilityText = accessibilityLabel
    }

    public var body: some View {
        Text(name)
            .font(Theme.Fonts.label)
            // One line normally; at the accessibility sizes a long name
            // wraps instead of losing its end.
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .foregroundStyle(color.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.background, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            .accessibilityLabel(accessibilityText ?? "Tag, \(name)")
    }
}
