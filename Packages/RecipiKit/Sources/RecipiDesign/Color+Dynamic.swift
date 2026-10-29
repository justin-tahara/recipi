import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// An sRGB color written as hex, e.g. `RGBA(0x37352F)`.
struct RGBA: Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(_ hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.alpha = alpha
    }
}

/// A color's light and dark mode values, kept as numbers so tests can check
/// their contrast.
struct ColorValues: Sendable {
    var light: RGBA
    var dark: RGBA

    /// The WCAG contrast ratio with `other`, in light and in dark mode.
    func contrast(with other: ColorValues) -> (light: Double, dark: Double) {
        (light.contrast(with: other.light), dark.contrast(with: other.dark))
    }
}

extension RGBA {
    /// WCAG 2 relative luminance. Alpha is ignored; blend first with
    /// `over(_:)`.
    var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// The WCAG contrast ratio between two opaque colors, 1 to 21.
    func contrast(with other: RGBA) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// This color, with its alpha, laid over an opaque background.
    func over(_ background: RGBA) -> RGBA {
        var blended = background
        blended.red = red * alpha + background.red * (1 - alpha)
        blended.green = green * alpha + background.green * (1 - alpha)
        blended.blue = blue * alpha + background.blue * (1 - alpha)
        blended.alpha = 1
        return blended
    }
}

extension Color {
    init(_ values: ColorValues) {
        self.init(light: values.light, dark: values.dark)
    }

    /// A color that follows light and dark mode.
    init(light: RGBA, dark: RGBA) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.red, green: value.green, blue: value.blue, alpha: value.alpha)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: value.alpha)
        })
        #endif
    }
}
