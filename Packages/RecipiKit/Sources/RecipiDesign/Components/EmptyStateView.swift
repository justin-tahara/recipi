import SwiftUI

/// What a screen shows when there's nothing in it yet: a symbol on a soft
/// colored tile, a line of explanation, and optional buttons.
public struct EmptyStateView<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    let color: TagColor
    let actions: Actions

    @State private var hasAppeared = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 30
    @ScaledMetric(relativeTo: .title) private var tileSize: CGFloat = 72

    public init(
        symbol: String,
        title: String,
        message: String,
        color: TagColor = .orange,
        @ViewBuilder actions: () -> Actions
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.color = color
        self.actions = actions()
    }

    /// Fills the space it's given and centers itself. It doesn't scroll; put
    /// it in a `ScrollView` where large text could make it taller than the
    /// screen.
    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color.foreground)
                .frame(width: tileSize, height: tileSize)
                .background(color.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .bounceEffect(value: hasAppeared)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Fonts.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(Theme.Fonts.meta)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Theme.Spacing.sm) {
                actions
            }
            // Wider at the accessibility sizes, so button titles don't wrap
            // a word per line.
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 280)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { hasAppeared = true }
    }
}

extension EmptyStateView where Actions == EmptyView {
    public init(symbol: String, title: String, message: String, color: TagColor = .orange) {
        self.init(symbol: symbol, title: title, message: message, color: color) { EmptyView() }
    }
}
