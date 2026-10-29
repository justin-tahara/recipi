import SwiftUI

/// A heading for a block of a page, with room for a count or note on the
/// right. VoiceOver reads both as one header, e.g. "Ingredients, 4".
public struct SectionHeader<Accessory: View>: View {
    let title: String
    let accessory: Accessory

    public init(_ title: String, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(Theme.Fonts.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer(minLength: Theme.Spacing.sm)
            accessory
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Accessory == EmptyView {
    public init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// A thin Notion-style rule between blocks.
public struct HairlineDivider: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Theme.Colors.divider)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
