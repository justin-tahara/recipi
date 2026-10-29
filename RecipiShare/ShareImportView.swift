import RecipiDesign
import SwiftUI

struct ShareImportView: View {
    let model: ShareImportModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                switch model.state {
                case .importing:
                    ProgressView()
                        .controlSize(.large)
                        .frame(width: 64, height: 64)
                    Text("Saving recipe…")
                        .font(Theme.Fonts.meta)
                        .foregroundStyle(Theme.Colors.textSecondary)
                case .saved(let title):
                    statusIcon("checkmark", color: .green)
                    Text("Saved \(title)")
                        .font(Theme.Fonts.rowTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                case .failed(let message):
                    statusIcon("exclamationmark.triangle.fill", color: .orange)
                    Text(message)
                        .font(Theme.Fonts.meta)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
            .id(phase)
            .motion(Motion.bouncy, value: phase)
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)
            .navigationTitle("recipi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { model.close() }
                }
            }
        }
        .tint(Theme.Colors.accent)
        .sensoryFeedback(.success, trigger: phase) { _, newValue in newValue == 1 }
    }

    /// 0 while importing, 1 once saved, 2 on failure. Drives the animation
    /// between states.
    private var phase: Int {
        switch model.state {
        case .importing: 0
        case .saved: 1
        case .failed: 2
        }
    }

    private func statusIcon(_ symbol: String, color: TagColor) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(color.foreground)
            .frame(width: 64, height: 64)
            .background(color.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .bounceEffect(value: phase)
            .accessibilityHidden(true)
    }
}
