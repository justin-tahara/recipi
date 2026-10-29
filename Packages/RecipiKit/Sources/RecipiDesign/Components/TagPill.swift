import SwiftUI

/// A tag as Notion draws one: a small rounded label in the tag's color.
public struct TagPill: View {
    let name: String
    let color: TagColor

    public init(_ name: String, color: TagColor? = nil) {
        self.name = name
        self.color = color ?? .forName(name)
    }

    public var body: some View {
        Text(name)
            .font(Theme.Fonts.label)
            .lineLimit(1)
            .foregroundStyle(color.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.background, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
    }
}
