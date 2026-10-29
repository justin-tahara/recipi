import SwiftUI

/// A compact minus / count / plus control. The count rolls like an
/// odometer when it changes.
public struct ServingsStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(value: Binding<Int>, in range: ClosedRange<Int> = 1...99) {
        _value = value
        self.range = range
    }

    public var body: some View {
        HStack(spacing: 0) {
            stepButton(symbol: "minus", delta: -1)
                .disabled(value <= range.lowerBound)
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText(value: Double(value)))
                .frame(minWidth: 28)
            stepButton(symbol: "plus", delta: 1)
                .disabled(value >= range.upperBound)
        }
        .padding(2)
        .background(Theme.Colors.fill, in: Capsule())
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Servings")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
    }

    private func stepButton(symbol: String, delta: Int) -> some View {
        Button {
            step(by: delta)
        } label: {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    private func step(by delta: Int) {
        let newValue = min(max(value + delta, range.lowerBound), range.upperBound)
        guard newValue != value else { return }
        withMotion(Motion.bouncy, reduceMotion: reduceMotion) {
            value = newValue
        }
    }
}
