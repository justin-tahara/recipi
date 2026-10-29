import SwiftUI

extension TagColor {
    /// The name a color is saved under when a person picks one for a tag.
    /// Fixed strings, so reordering cases never changes what's saved.
    public var storageName: String {
        switch self {
        case .gray: "gray"
        case .brown: "brown"
        case .orange: "orange"
        case .yellow: "yellow"
        case .green: "green"
        case .blue: "blue"
        case .purple: "purple"
        case .pink: "pink"
        case .red: "red"
        }
    }

    /// The color saved under `storageName`, or nil for none or an unknown
    /// name.
    public init?(storageName: String?) {
        guard let storageName, let match = TagColor.allCases.first(where: { $0.storageName == storageName }) else {
            return nil
        }
        self = match
    }

    /// The name shown to people, e.g. in the tag color picker.
    public var displayName: String {
        storageName.prefix(1).uppercased() + storageName.dropFirst()
    }

    /// The colors a person can pick for a tag: the same ones names hash to.
    public static var tagChoices: [TagColor] { tagPalette }

    /// A tag's color: the one picked for it, or the one its name hashes to.
    public static func forTag(named name: String, override: String?) -> TagColor {
        TagColor(storageName: override) ?? .forName(name)
    }
}
