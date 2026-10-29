import SwiftUI

/// A heading for a block of a page, with room for a control on the right.
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
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Theme.Spacing.sm)
            accessory
        }
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
