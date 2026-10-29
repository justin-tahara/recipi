import SwiftUI

/// The few animations recipi uses, so movement feels the same everywhere.
/// Anything that moves goes through these helpers, which turn the movement
/// off when Reduce Motion is on.
public enum Motion {
    /// Quick and settled: rows moving, chips, toggles.
    public static var snappy: Animation { .snappy(duration: 0.28) }
    /// A little overshoot for things that deserve a moment: checks, counts.
    public static var bouncy: Animation { .spring(response: 0.38, dampingFraction: 0.66) }
    /// Soft fades and size changes.
    public static var smooth: Animation { .smooth(duration: 0.35) }
}

/// `withAnimation`, minus the animation when Reduce Motion is on.
public func withMotion<Result>(
    _ animation: Animation,
    reduceMotion: Bool,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(reduceMotion ? nil : animation, body)
}

extension View {
    /// `.animation(_:value:)`, minus the animation when Reduce Motion is on.
    public func motion<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }

    /// Bounces an SF Symbol each time `value` changes, unless Reduce Motion
    /// is on.
    public func bounceEffect<Value: Equatable>(value: Value) -> some View {
        modifier(BounceModifier(value: value))
    }
}

private struct MotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

private struct BounceModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.symbolEffect(.bounce, value: value)
        }
    }
}
