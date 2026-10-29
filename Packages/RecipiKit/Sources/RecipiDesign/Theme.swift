import SwiftUI

/// recipi's look: Notion-like warm neutrals, clean system type and plenty of
/// room, with color saved for the things that matter (tags, the accent on
/// actions, callouts). Every color has a light and a dark value.
public enum Theme {
    public enum Colors {
        /// The page itself.
        public static let background = Color(Values.background)
        /// A quieter panel behind grouped content, like Notion's sidebar.
        public static let surface = Color(Values.surface)
        /// Cards and floating things that sit above the page.
        public static let elevated = Color(Values.elevated)
        /// The faint fill behind a pressed row, a field or an idle chip.
        public static let fill = Color(Values.fill)

        public static let textPrimary = Color(Values.textPrimary)
        /// Meta text, captions and footnotes.
        public static let textSecondary = Color(Values.textSecondary)
        /// The quietest text: counts, finished items, small labels. Still
        /// passes WCAG AA on the page, surface and elevated colors.
        public static let textTertiary = Color(Values.textTertiary)

        public static let divider = Color(light: RGBA(0x37352F, alpha: 0.09), dark: RGBA(0xFFFFFF, alpha: 0.09))
        public static let border = Color(light: RGBA(0x37352F, alpha: 0.16), dark: RGBA(0xFFFFFF, alpha: 0.14))

        /// Paprika. Matches the AccentColor asset. A shade deeper than the
        /// logo's in light mode, so it passes WCAG AA as text and behind
        /// white text.
        public static let accent = Color(Values.accent)
        /// A faint wash of the accent, e.g. behind step numbers.
        public static let accentSoft = Color(Values.accentSoft)
        /// Text and icons on an accent fill: white in light mode, near-black
        /// on the brighter dark-mode paprika.
        public static let onAccent = Color(Values.onAccent)

        /// The numbers behind the colors above, so `ContrastTests` can
        /// check text against what it sits on (WCAG AA is 4.5:1 for text).
        enum Values {
            static let background = ColorValues(light: RGBA(0xFFFFFF), dark: RGBA(0x191919))
            static let surface = ColorValues(light: RGBA(0xF7F7F5), dark: RGBA(0x202020))
            static let elevated = ColorValues(light: RGBA(0xFFFFFF), dark: RGBA(0x262626))
            static let fill = ColorValues(light: RGBA(0x37352F, alpha: 0.06), dark: RGBA(0xFFFFFF, alpha: 0.06))
            static let textPrimary = ColorValues(light: RGBA(0x37352F), dark: RGBA(0xE6E5E3))
            static let textSecondary = ColorValues(light: RGBA(0x5B5B58), dark: RGBA(0xAFAFAF))
            static let textTertiary = ColorValues(light: RGBA(0x71706B), dark: RGBA(0x8E8E8E))
            static let accent = ColorValues(light: RGBA(0xB04D22), dark: RGBA(0xE8804F))
            static let accentSoft = ColorValues(light: RGBA(0xB04D22, alpha: 0.06), dark: RGBA(0xE8804F, alpha: 0.12))
            static let onAccent = ColorValues(light: RGBA(0xFFFFFF), dark: RGBA(0x191919))
        }
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
