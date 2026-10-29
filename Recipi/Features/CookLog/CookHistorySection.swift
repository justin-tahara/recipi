import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

/// "Your cooks" on the recipe page: a row of cards, one per time it was
/// cooked, with the photo and note. Long-press a card to use its photo as
/// the cover or delete it.
struct CookHistorySection: View {
    @Bindable var recipe: Recipe
    var onLogCook: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Cards grow with Dynamic Type so their text still fits.
    @ScaledMetric(relativeTo: .footnote) private var cardSize: CGFloat = 120

    var body: some View {
        let logs = recipe.sortedCookLogs
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Your cooks") {
                Text("\(logs.count)")
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .contentTransition(.numericText(value: Double(logs.count)))
                    .accessibilityLabel(logs.count == 1 ? "1 cook" : "\(logs.count) cooks")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    addCard
                    ForEach(logs) { log in
                        card(for: log)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 2)
            }
            .padding(.horizontal, -Theme.Spacing.page)
            .motion(Motion.bouncy, value: logs.map(\.persistentModelID))
        }
    }

    private var addCard: some View {
        Button(action: onLogCook) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .accessibilityHidden(true)
                Text("I made this")
                    .font(Theme.Fonts.label)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Theme.Colors.accent)
            .padding(Theme.Spacing.xs)
            .frame(width: cardSize, height: cardSize)
            .background(Theme.Colors.accentSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private func card(for log: CookLog) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Group {
                if log.photoData != nil {
                    RecipePhoto(data: log.photoData, title: recipe.title)
                } else {
                    Rectangle()
                        .fill(Theme.Colors.fill)
                        .overlay {
                            Image(systemName: "checkmark.seal")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .accessibilityHidden(true)
                }
            }
            .frame(width: cardSize, height: cardSize)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(Theme.Colors.divider, lineWidth: 0.5)
            }

            Text(log.cookedAt.formatted(date: .abbreviated, time: .omitted))
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textSecondary)
            if !log.note.isEmpty {
                Text(log.note)
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
            }
        }
        .frame(width: cardSize, alignment: .leading)
        // "Cooked Oct 3, 2026, with a photo", then the note. The long-press
        // menu's actions are VoiceOver actions too.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.voiceOverLabel(for: log))
        .accessibilityValue(log.note)
        .accessibilityActions {
            if log.photoData != nil {
                Button("Use as cover photo") { useAsCover(log) }
            }
            Button("Delete") { delete(log) }
        }
        .contextMenu {
            if log.photoData != nil {
                Button("Use as cover photo", systemImage: "photo") { useAsCover(log) }
            }
            Button("Delete", systemImage: "trash", role: .destructive) { delete(log) }
        }
    }

    private static func voiceOverLabel(for log: CookLog) -> String {
        let date = "Cooked \(log.cookedAt.formatted(date: .abbreviated, time: .omitted))"
        return log.photoData == nil ? date : "\(date), with a photo"
    }

    private func useAsCover(_ log: CookLog) {
        withMotion(Motion.smooth, reduceMotion: reduceMotion) {
            recipe.photoData = log.photoData
        }
    }

    private func delete(_ log: CookLog) {
        withMotion(Motion.snappy, reduceMotion: reduceMotion) {
            recipe.deleteCookLog(log, in: modelContext)
        }
    }
}
