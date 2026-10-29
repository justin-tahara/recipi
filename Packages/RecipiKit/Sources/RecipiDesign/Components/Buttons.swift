import SwiftUI

/// The one strong button on a screen: full width, filled with the accent.
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, isPrimary: true)
    }
}

/// A quiet button: neutral fill with a hairline border.
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, isPrimary: false)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    public static var recipiPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    public static var recipiSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Shrinks a touch while pressed, for custom rows and chips.
public struct PressableButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration)
    }

    private struct PressableBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.35)
                .animation(reduceMotion ? nil : Motion.snappy, value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    public static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

private struct StyledButton: View {
    let configuration: ButtonStyleConfiguration
    let isPrimary: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isPrimary ? Theme.Colors.onAccent : Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, Theme.Spacing.md)
            .background {
                if isPrimary {
                    shape.fill(Theme.Colors.accent)
                } else {
                    shape.fill(Theme.Colors.fill)
                    shape.strokeBorder(Theme.Colors.border, lineWidth: 0.5)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : Motion.snappy, value: configuration.isPressed)
    }
}
