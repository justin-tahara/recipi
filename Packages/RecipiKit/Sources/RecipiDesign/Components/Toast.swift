import SwiftUI

extension View {
    /// Shows `message` in a small pill near the bottom for a couple of
    /// seconds, then clears it. Lighter than an alert for "done" news.
    public func toast(
        _ message: Binding<String?>,
        symbol: String = "checkmark.circle.fill",
        bottomPadding: CGFloat = Theme.Spacing.xl
    ) -> some View {
        modifier(ToastModifier(message: message, symbol: symbol, bottomPadding: bottomPadding))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let symbol: String
    let bottomPadding: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                ZStack {
                    if let message {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: symbol)
                                .foregroundStyle(TagColor.green.foreground)
                            Text(message)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.elevated, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.Colors.border, lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
                        .padding(.bottom, bottomPadding)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.bouncy, value: message)
            }
            .task(id: message) {
                guard let message else { return }
                AccessibilityNotification.Announcement(message).post()
                do {
                    try await Task.sleep(for: .seconds(2.2))
                    self.message = nil
                } catch {
                    // A newer message replaced this one.
                }
            }
    }
}
