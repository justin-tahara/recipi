import Foundation

/// Writes scaled amounts the way a cook would: "1½", "⅔", "2.25" only when
/// no kitchen fraction is close.
enum QuantityFormatter {
    private static let fractions: [(value: Double, glyph: String)] = [
        (0, ""), (1.0 / 8, "⅛"), (1.0 / 4, "¼"), (1.0 / 3, "⅓"), (3.0 / 8, "⅜"),
        (1.0 / 2, "½"), (5.0 / 8, "⅝"), (2.0 / 3, "⅔"), (3.0 / 4, "¾"), (7.0 / 8, "⅞"), (1, ""),
    ]

    static func string(from value: Double) -> String {
        guard value.isFinite, value > 0 else { return "0" }
        var whole = value.rounded(.down)
        let remainder = value - whole

        if value < 20, let nearest = fractions.min(by: { abs($0.value - remainder) < abs($1.value - remainder) }),
           abs(nearest.value - remainder) < 0.02 {
            if nearest.value == 1 { whole += 1 }
            let wholeText = whole > 0 ? String(Int(whole)) : ""
            let text = wholeText + nearest.glyph
            return text.isEmpty ? "0" : text
        }

        let decimals = value < 10 ? 2 : (value < 100 ? 1 : 0)
        var text = String(format: "%.\(decimals)f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }
}
