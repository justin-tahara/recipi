import SwiftUI

/// Notion's callout block: an icon and some text on a soft colored panel.
public struct Callout<Content: View>: View {
    let symbol: String
    let color: TagColor
    let content: Content

    public init(symbol: String, color: TagColor = .yellow, @ViewBuilder content: () -> Content) {
        self.symbol = symbol
        self.color = color
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(color.foreground)
                .accessibilityHidden(true)
            content
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.md)
        .background(color.background, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}
