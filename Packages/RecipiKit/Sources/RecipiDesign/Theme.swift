import SwiftUI

/// recipi's look: Notion-like warm neutrals, clean system type and plenty of
/// room, with color saved for the things that matter (tags, the accent on
/// actions, callouts). Every color has a light and a dark value.
public enum Theme {
    public enum Colors {
        /// The page itself.
        public static let background = Color(light: RGBA(0xFFFFFF), dark: RGBA(0x191919))
        /// A quieter panel behind grouped content, like Notion's sidebar.
        public static let surface = Color(light: RGBA(0xF7F7F5), dark: RGBA(0x202020))
        /// Cards and floating things that sit above the page.
        public static let elevated = Color(light: RGBA(0xFFFFFF), dark: RGBA(0x262626))
        /// The faint fill behind a pressed row, a field or an idle chip.
        public static let fill = Color(light: RGBA(0x37352F, alpha: 0.06), dark: RGBA(0xFFFFFF, alpha: 0.06))

        public static let textPrimary = Color(light: RGBA(0x37352F), dark: RGBA(0xE6E5E3))
        public static let textSecondary = Color(light: RGBA(0x787774), dark: RGBA(0x9B9B9B))
        public static let textTertiary = Color(light: RGBA(0xA5A4A0), dark: RGBA(0x6F6F6F))

        public static let divider = Color(light: RGBA(0x37352F, alpha: 0.09), dark: RGBA(0xFFFFFF, alpha: 0.09))
        public static let border = Color(light: RGBA(0x37352F, alpha: 0.16), dark: RGBA(0xFFFFFF, alpha: 0.14))

        /// Paprika. Matches the AccentColor asset.
        public static let accent = Color(light: RGBA(0xD96B3B), dark: RGBA(0xE8804F))
        public static let accentSoft = Color(light: RGBA(0xD96B3B, alpha: 0.12), dark: RGBA(0xE8804F, alpha: 0.18))
        public static let onAccent = Color.white
    }

    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
        /// Side margin for page content.
        public static let page: CGFloat = 20
    }

    public enum Radius {
        /// Tag pills and checkboxes.
        public static let small: CGFloat = 5
        /// Thumbnails, fields and callouts.
        public static let medium: CGFloat = 10
        /// Buttons and cards.
        public static let large: CGFloat = 14
    }

    /// Text styles, all built on Dynamic Type sizes so they scale.
    public enum Fonts {
        public static var pageTitle: Font { .system(.largeTitle, design: .default, weight: .bold) }
        public static var sectionTitle: Font { .system(.title3, design: .default, weight: .semibold) }
        public static var rowTitle: Font { .system(.body, design: .default, weight: .semibold) }
        public static var body: Font { .body }
        public static var meta: Font { .subheadline }
        public static var label: Font { .system(.footnote, design: .default, weight: .medium) }
        /// Small uppercase label above a block, e.g. "STEP 2".
        public static var eyebrow: Font { .system(.caption, design: .default, weight: .semibold) }
        /// The step being cooked, big enough to read from the counter.
        public static var step: Font { .system(.title2, design: .default, weight: .regular) }
    }
}
