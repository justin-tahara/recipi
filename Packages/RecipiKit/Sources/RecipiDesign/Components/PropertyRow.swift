import SwiftUI

/// One line of a Notion-style property list: an icon and name on the left,
/// the value on the right.
public struct PropertyRow<Content: View>: View {
    let label: String
    let symbol: String
    let content: Content

    public init(_ label: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.symbol = symbol
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: symbol)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                Text(label)
                    .lineLimit(1)
            }
            .font(Theme.Fonts.meta)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(width: 116, alignment: .leading)

            content
                .font(Theme.Fonts.meta)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}
