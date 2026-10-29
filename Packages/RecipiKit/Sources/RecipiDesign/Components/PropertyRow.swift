import SwiftUI

/// One line of a Notion-style property list: an icon and name on the left,
/// the value on the right. At the accessibility text sizes the value moves
/// under the name so neither gets cut off.
///
/// VoiceOver reads a plain value with its name, as one element ("Prep, 10
/// min"). A control (a menu, stepper or link) carries its own label, so the
/// row leaves it alone and keeps the name out of the way.
public struct PropertyRow<Content: View>: View {
    let label: String
    let symbol: String
    let isInteractive: Bool
    let content: Content

    @ScaledMetric(relativeTo: .subheadline) private var labelWidth: CGFloat = 116
    @ScaledMetric(relativeTo: .subheadline) private var iconWidth: CGFloat = 18
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameter isInteractive: True when `content` is a control with its
    ///   own accessibility label.
    public init(_ label: String, symbol: String, isInteractive: Bool = false, @ViewBuilder content: () -> Content) {
        self.label = label
        self.symbol = symbol
        self.isInteractive = isInteractive
        self.content = content()
    }

    public var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Theme.Spacing.sm))
        let row = layout {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: symbol)
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)
                Text(label)
                    .lineLimit(isLarge ? nil : 1)
            }
            .font(Theme.Fonts.meta)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(width: isLarge ? nil : labelWidth, alignment: .leading)
            .accessibilityHidden(isInteractive)

            content
                .font(Theme.Fonts.meta)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Tall enough for a 44 pt control, so every row lines up.
        .frame(minHeight: 44)
        .padding(.vertical, isLarge ? Theme.Spacing.xxs : 0)

        if isInteractive {
            row.accessibilityElement(children: .contain)
        } else {
            row.accessibilityElement(children: .combine)
        }
    }
}
