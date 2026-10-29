import SwiftUI

/// A Notion-style to-do box that fills with a little spring when ticked.
/// Decorative: put the label and the checked state on the row around it.
public struct Checkbox: View {
    let isOn: Bool
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.Colors.onAccent)
                .scaleEffect(isOn ? 1 : 0.3)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: 22, height: 22)
        .animation(reduceMotion ? nil : Motion.bouncy, value: isOn)
        .accessibilityHidden(true)
    }
}
