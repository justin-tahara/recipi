import SwiftUI

/// Notion's tag palette: a soft background with a deeper text color of the
/// same hue, tuned separately for light and dark mode.
public enum TagColor: CaseIterable, Sendable {
    case gray, brown, orange, yellow, green, blue, purple, pink, red

    public var foreground: Color { Color(foregroundValues) }

    public var background: Color { Color(backgroundValues) }

    /// The text color's light and dark values. Each passes WCAG AA (4.5:1)
    /// on the tag's own background and on the page (`TagColorTests`
    /// checks), so a pill, a chip or red warning text stays readable. A
    /// shade can change within its hue; the case and palette order can't.
    var foregroundValues: ColorValues {
        switch self {
        case .gray: ColorValues(light: RGBA(0x6D6C69), dark: RGBA(0x9B9B9B))
        case .brown: ColorValues(light: RGBA(0x8F604B), dark: RGBA(0xC59885))
        case .orange: ColorValues(light: RGBA(0xA3560A), dark: RGBA(0xD8A681))
        case .yellow: ColorValues(light: RGBA(0x8F6621), dark: RGBA(0xD6B073))
        case .green: ColorValues(light: RGBA(0x3E7859), dark: RGBA(0x68B187))
        case .blue: ColorValues(light: RGBA(0x2E7299), dark: RGBA(0x54A9D9))
        case .purple: ColorValues(light: RGBA(0x8759AA), dark: RGBA(0xB48BDD))
        case .pink: ColorValues(light: RGBA(0xB73F7F), dark: RGBA(0xDD85B3))
        case .red: ColorValues(light: RGBA(0xC7342E), dark: RGBA(0xE98786))
        }
    }

    var backgroundValues: ColorValues {
        switch self {
        case .gray: ColorValues(light: RGBA(0xF1F1EF), dark: RGBA(0x2F2F2F))
        case .brown: ColorValues(light: RGBA(0xF4EEEE), dark: RGBA(0x4A3228))
        case .orange: ColorValues(light: RGBA(0xFBECDD), dark: RGBA(0x5C3B23))
        case .yellow: ColorValues(light: RGBA(0xFBF3DB), dark: RGBA(0x564328))
        case .green: ColorValues(light: RGBA(0xEDF3EC), dark: RGBA(0x243D30))
        case .blue: ColorValues(light: RGBA(0xE7F3F8), dark: RGBA(0x143A4E))
        case .purple: ColorValues(light: RGBA(0xF4F0F7), dark: RGBA(0x3C2D49))
        case .pink: ColorValues(light: RGBA(0xF9EEF3), dark: RGBA(0x4E2C3C))
        case .red: ColorValues(light: RGBA(0xFDEBEC), dark: RGBA(0x522E2A))
        }
    }

    /// Colors handed out to tags. Gray is left for neutral things.
    static let tagPalette: [TagColor] = [.orange, .green, .blue, .purple, .pink, .yellow, .red, .brown]

    /// The same name gets the same color on every launch and every device,
    /// so a tag never changes color between the library and a recipe.
    /// (String.hashValue is seeded per launch, so it can't be used here.)
    public static func forName(_ name: String) -> TagColor {
        var hash: UInt64 = 5381
        for byte in name.lowercased().utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return tagPalette[Int(hash % UInt64(tagPalette.count))]
    }
}
