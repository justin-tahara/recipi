import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI
// TranslationSession isn't Sendable. It's only used inside the
// `.translationTask` action, on the main actor, and never stored.
@preconcurrency import Translation

/// A small callout under a recipe's title when the recipe is in another
/// language: "This recipe is in French. Translate to English", then
/// "Translated from French · Show original". Translation runs on the
/// device with Apple's Translation framework; the first time, iOS may ask
/// to download the language. recipi sends nothing anywhere.
///
/// Shows nothing for recipes already in the reader's language, when the
/// language couldn't be told, or when Settings says don't translate.
struct TranslationBanner: View {
    @Bindable var recipe: Recipe

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var preferences = Preferences()
    /// Set (or invalidated) to start a translation; `.translationTask` runs
    /// whenever it changes.
    @State private var configuration: TranslationSession.Configuration?
    /// The language the running translation goes into.
    @State private var pendingTarget: String?
    /// Whether this device can translate between the two languages.
    @State private var availability: LanguageAvailability.Status?
    @State private var isTranslating = false
    @State private var failureMessage: String?
    @State private var isConfirmingShowOriginal = false

    var body: some View {
        if let mode {
            Callout(symbol: symbol(for: mode), color: mode.isOffer && availability == .unsupported ? .gray : .blue) {
                content(for: mode)
                    .font(Theme.Fonts.meta)
            }
            .motion(Motion.smooth, value: contentKey)
            .translationTask(configuration) { session in
                await translate(using: session)
            }
            .task(id: availabilityKey) {
                await checkAvailability()
            }
            .confirmationDialog(
                "Show the original recipe?",
                isPresented: $isConfirmingShowOriginal,
                titleVisibility: .visible
            ) {
                Button("Show original", role: .destructive, action: showOriginal)
                Button("Keep translation", role: .cancel) {}
            } message: {
                Text("You've edited this translation. The original replaces it, edits included.")
            }
        }
    }

    // MARK: - What to show

    private enum Mode: Equatable {
        /// The recipe is in `source`; offer to translate it into `target`.
        case offer(source: String, target: String)
        /// The recipe shows a translation from `source` (nil if unknown)
        /// into `target`.
        case translated(source: String?, target: String)

        var isOffer: Bool {
            if case .offer = self { return true }
            return false
        }
    }

    private var mode: Mode? {
        if let translated = recipe.translatedLanguage {
            return .translated(source: sourceLanguage, target: translated)
        }
        guard let sourceLanguage, let targetLanguage, !RecipeLanguage.isSame(sourceLanguage, as: targetLanguage) else {
            return nil
        }
        return .offer(source: sourceLanguage, target: targetLanguage)
    }

    private var sourceLanguage: String? {
        guard let language = recipe.originalLanguage, language != RecipeLanguage.undetermined else { return nil }
        return language
    }

    private var targetLanguage: String? {
        preferences.recipeLanguage.targetLanguage()
    }

    @ViewBuilder
    private func content(for mode: Mode) -> some View {
        switch mode {
        case .offer(let source, let target):
            if isTranslating {
                HStack(spacing: Theme.Spacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Translating to \(name(target))…")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .accessibilityElement(children: .combine)
            } else if let failureMessage {
                row(failureMessage) {
                    actionButton("Try again") { startTranslation(to: target) }
                }
            } else if availability == .unsupported {
                Text("This recipe is in \(name(source)). Translating \(name(source)) into \(name(target)) isn't available on this device yet.")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                row("This recipe is in \(name(source)).") {
                    actionButton("Translate to \(name(target))") { startTranslation(to: target) }
                }
            }
        case .translated(let source, _):
            row(source.map { "Translated from \(name($0))" } ?? "Translated") {
                actionButton("Show original", action: confirmShowOriginal)
            }
        }
    }

    private func row<Action: View>(_ message: String, @ViewBuilder action: () -> Action) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
            Text(message)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            action()
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderless)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.Colors.accent)
            .multilineTextAlignment(.trailing)
    }

    private func symbol(for mode: Mode) -> String {
        if case .offer = mode, failureMessage != nil { return "exclamationmark.bubble" }
        return "character.bubble"
    }

    private func name(_ language: String) -> String {
        RecipeLanguage.displayName(for: language)
    }

    /// Changes when the callout's text does, to fade between them.
    private var contentKey: String {
        "\(String(describing: mode))|\(isTranslating)|\(failureMessage ?? "")|\(String(describing: availability))"
    }

    /// Changes when the languages, the translation or the automatic setting
    /// do, so availability is checked again.
    private var availabilityKey: String {
        "\(sourceLanguage ?? "")>\(targetLanguage ?? "")|\(recipe.translatedLanguage ?? "")|\(preferences.translatesAutomatically)"
    }

    // MARK: - Translating

    /// Looks up whether the languages are installed, supported or not
    /// supported here, and translates straight away when the person asked
    /// for that and nothing needs downloading.
    private func checkAvailability() async {
        guard let sourceLanguage, let targetLanguage, !RecipeLanguage.isSame(sourceLanguage, as: targetLanguage) else {
            availability = nil
            return
        }
        let status = await LanguageAvailability().status(
            from: Locale.Language(identifier: sourceLanguage),
            to: Locale.Language(identifier: targetLanguage)
        )
        availability = status

        guard preferences.translatesAutomatically, status == .installed, !isTranslating, failureMessage == nil else {
            return
        }
        if let translated = recipe.translatedLanguage {
            // Settings changed to another language: translate the original
            // again, unless the person has edited the translation.
            if !RecipeLanguage.isSame(translated, as: targetLanguage), !recipe.hasEditedTranslation {
                startTranslation(to: targetLanguage)
            }
        } else if !recipe.keepsOriginalLanguage {
            startTranslation(to: targetLanguage)
        }
    }

    private func startTranslation(to target: String) {
        guard let sourceLanguage else { return }
        let source = Locale.Language(identifier: sourceLanguage)
        let targetLanguage = Locale.Language(identifier: target)
        pendingTarget = target
        failureMessage = nil
        isTranslating = true
        if configuration?.source == source, configuration?.target == targetLanguage {
            // Same languages as last time: run the task again.
            configuration?.invalidate()
        } else {
            configuration = TranslationSession.Configuration(source: source, target: targetLanguage)
        }
    }

    /// Translates the original title, summary, headings, ingredients and
    /// steps in one batch and shows the result.
    private func translate(using session: TranslationSession) async {
        guard let target = pendingTarget else { return }
        pendingTarget = nil
        defer { isTranslating = false }

        let plan = RecipeTranslationPlan(recipe.translationSource)
        guard !plan.segments.isEmpty else { return }
        do {
            let responses = try await session.translations(from: Self.requests(for: plan.segments))
            var translations: [String: String] = [:]
            for response in responses {
                if let id = response.clientIdentifier {
                    translations[id] = response.targetText
                }
            }
            let translated = plan.apply(translations)
            withMotion(Motion.smooth, reduceMotion: reduceMotion) {
                recipe.applyTranslation(translated, of: plan.source, to: target, in: modelContext)
            }
        } catch is CancellationError {
            // The recipe was closed mid-way; nothing changed.
        } catch {
            failureMessage = failureText(target: target)
        }
    }

    /// One request per segment, tagged with its id. Built outside the main
    /// actor because requests aren't Sendable and go straight to the
    /// session.
    private nonisolated static func requests(for segments: [RecipeTranslationPlan.Segment]) -> [TranslationSession.Request] {
        var requests: [TranslationSession.Request] = []
        for segment in segments {
            requests.append(TranslationSession.Request(sourceText: segment.text, clientIdentifier: segment.id))
        }
        return requests
    }

    /// The download may have been turned down or still be in progress, or
    /// the pair isn't supported after all. None of it is the person's fault.
    private func failureText(target: String) -> String {
        guard let sourceLanguage else { return "This recipe couldn't be translated." }
        if availability == .supported {
            return "Translating needs \(name(sourceLanguage)) and \(name(target)) downloaded on this device. "
                + "Try again to download them, or add them in Settings › Apps › Translate."
        }
        return "This recipe couldn't be translated from \(name(sourceLanguage)) right now."
    }

    // MARK: - Showing the original

    private func confirmShowOriginal() {
        if recipe.hasEditedTranslation {
            isConfirmingShowOriginal = true
        } else {
            showOriginal()
        }
    }

    private func showOriginal() {
        failureMessage = nil
        withMotion(Motion.smooth, reduceMotion: reduceMotion) {
            recipe.showOriginal(in: modelContext)
        }
    }
}

extension View {
    /// Tells which language `recipe` is in the first time it's shown, so
    /// `TranslationBanner` knows whether to offer a translation.
    func detectsRecipeLanguage(_ recipe: Recipe) -> some View {
        onAppear { recipe.detectLanguageIfNeeded() }
    }
}
