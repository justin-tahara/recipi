import Testing
@testable import RecipiDesign

struct TagColorTests {
    @Test func sameNameSameColor() {
        #expect(TagColor.forName("Dinner") == TagColor.forName("dinner"))
    }

    /// Pinned so a tag keeps its color across releases. Changing the hash
    /// or the palette order would recolor everyone's tags.
    @Test(arguments: [
        ("dinner", TagColor.yellow),
        ("vegetarian", .purple),
        ("quick", .blue),
        ("dessert", .brown),
    ])
    func colorsAreStable(name: String, expected: TagColor) {
        #expect(TagColor.forName(name) == expected)
    }

    @Test func tagsNeverGetGray() {
        #expect(!TagColor.tagPalette.contains(.gray))
    }
}
