import SwiftUI

/// A Notion-style to-do box that fills with a little spring when ticked.
/// Decorative: put the label and the checked state on the row around it,
/// e.g. with `.checkedState(_:)`.
public struct Checkbox: View {
    let isOn: Bool
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Grows with Dynamic Type so the box keeps up with its row's text.
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 22

    public init(isOn: Bool, tint: Color = Theme.Colors.accent) {
        self.isOn = isOn
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(isOn ? tint : Color.clear)
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .strokeBorder(isOn ? tint : Theme.Colors.border, lineWidth: 1.5)
            // Only there when ticked: an invisible glyph still counts as
            // text that doesn't grow, for the accessibility audit.
            if isOn {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.Colors.onAccent)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : Motion.bouncy, value: isOn)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Tells VoiceOver whether a row with a `Checkbox` is ticked: it reads
    /// "Checked" or "Not checked" after the row's label. A value rather
    /// than the toggle trait, so the row stays a plain button.
    public func checkedState(_ isChecked: Bool) -> some View {
        accessibilityValue(isChecked ? "Checked" : "Not checked")
    }
}
