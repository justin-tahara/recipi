import Testing
@testable import RecipiDesign

/// Text colors against what they sit on, in light and dark mode. WCAG AA
/// asks for 4.5:1 for text of any size.
struct ContrastTests {
    private static let minimum = 4.5
    private typealias Values = Theme.Colors.Values

    @Test func contrastMatchesKnownPairs() {
        // Black on white is the maximum, 21:1; equal colors are 1:1.
        #expect(abs(RGBA(0x000000).contrast(with: RGBA(0xFFFFFF)) - 21) < 0.01)
        #expect(abs(RGBA(0x777777).contrast(with: RGBA(0x777777)) - 1) < 0.0001)
        // #767676 on white is the classic "just passes AA" gray.
        #expect(RGBA(0x767676).contrast(with: RGBA(0xFFFFFF)) >= Self.minimum)
    }

    @Test(arguments: TagColor.allCases)
    func tagTextIsReadableOnItsPill(color: TagColor) {
        let ratio = color.foregroundValues.contrast(with: color.backgroundValues)
        #expect(ratio.light >= Self.minimum, "\(color) light: \(ratio.light)")
        #expect(ratio.dark >= Self.minimum, "\(color) dark: \(ratio.dark)")
    }

    /// Tag colors are also used as text straight on the page, e.g. red
    /// warnings in a form.
    @Test(arguments: TagColor.allCases)
    func tagTextIsReadableOnThePage(color: TagColor) {
        for page in [Values.background, Values.surface, Values.elevated] {
            let ratio = color.foregroundValues.contrast(with: page)
            #expect(ratio.light >= Self.minimum, "\(color) light: \(ratio.light)")
            #expect(ratio.dark >= Self.minimum, "\(color) dark: \(ratio.dark)")
        }
    }

    @Test func themeTextIsReadable() {
        let pages = [Values.background, Values.surface, Values.elevated]
        for text in [Values.textPrimary, Values.textSecondary, Values.textTertiary] {
            for page in pages {
                let ratio = text.contrast(with: page)
                #expect(ratio.light >= Self.minimum, "light: \(ratio.light)")
                #expect(ratio.dark >= Self.minimum, "dark: \(ratio.dark)")
            }
        }
    }

    /// Secondary text also sits on `fill`: chips, fields and pills.
    @Test func secondaryTextIsReadableOnFill() {
        for page in [Values.background, Values.surface, Values.elevated] {
            let fill = ColorValues(light: Values.fill.light.over(page.light), dark: Values.fill.dark.over(page.dark))
            let ratio = Values.textSecondary.contrast(with: fill)
            #expect(ratio.light >= Self.minimum, "light: \(ratio.light)")
            #expect(ratio.dark >= Self.minimum, "dark: \(ratio.dark)")
        }
    }
}
