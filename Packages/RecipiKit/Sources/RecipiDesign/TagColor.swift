import SwiftUI

/// Notion's tag palette: a soft background with a deeper text color of the
/// same hue, tuned separately for light and dark mode.
public enum TagColor: CaseIterable, Sendable {
    case gray, brown, orange, yellow, green, blue, purple, pink, red

    public var foreground: Color {
        switch self {
        case .gray: Color(light: RGBA(0x787774), dark: RGBA(0x9B9B9B))
        case .brown: Color(light: RGBA(0x9F6B53), dark: RGBA(0xBA856F))
        case .orange: Color(light: RGBA(0xD9730D), dark: RGBA(0xC77D48))
        case .yellow: Color(light: RGBA(0xCB912F), dark: RGBA(0xCA9849))
        case .green: Color(light: RGBA(0x448361), dark: RGBA(0x529E72))
        case .blue: Color(light: RGBA(0x337EA9), dark: RGBA(0x379AD3))
        case .purple: Color(light: RGBA(0x9065B0), dark: RGBA(0x9D68D3))
        case .pink: Color(light: RGBA(0xC14C8A), dark: RGBA(0xD15796))
        case .red: Color(light: RGBA(0xD44C47), dark: RGBA(0xDF5452))
        }
    }

    public var background: Color {
        switch self {
        case .gray: Color(light: RGBA(0xF1F1EF), dark: RGBA(0x2F2F2F))
        case .brown: Color(light: RGBA(0xF4EEEE), dark: RGBA(0x4A3228))
        case .orange: Color(light: RGBA(0xFBECDD), dark: RGBA(0x5C3B23))
        case .yellow: Color(light: RGBA(0xFBF3DB), dark: RGBA(0x564328))
        case .green: Color(light: RGBA(0xEDF3EC), dark: RGBA(0x243D30))
        case .blue: Color(light: RGBA(0xE7F3F8), dark: RGBA(0x143A4E))
        case .purple: Color(light: RGBA(0xF4F0F7), dark: RGBA(0x3C2D49))
        case .pink: Color(light: RGBA(0xF9EEF3), dark: RGBA(0x4E2C3C))
        case .red: Color(light: RGBA(0xFDEBEC), dark: RGBA(0x522E2A))
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
