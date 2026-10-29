import RecipiDesign
import RecipiKit
import SwiftUI
@preconcurrency import Translation

/// Settings › Language: which language recipes are shown in, and whether
/// they're translated as soon as they open or only when the person taps
/// Translate. See `TranslationBanner`.
struct TranslationSettingsSection: View {
    @Bindable var preferences: Preferences

    /// Languages this device can translate into, by code, sorted by name.
    @State private var languages: [String] = []

    var body: some View {
        Section {
            Picker(selection: $preferences.recipeLanguage) {
                Text("Device language (\(RecipeLanguage.displayName(for: RecipeLanguage.deviceLanguage)))")
                    .tag(RecipeLanguageChoice.deviceLanguage)
                ForEach(pickableLanguages, id: \.self) { code in
                    Text(RecipeLanguage.displayName(for: code, includingRegion: true))
                        .tag(RecipeLanguageChoice.language(code))
                }
                Text("Don't translate")
                    .tag(RecipeLanguageChoice.dontTranslate)
            } label: {
                Label("Recipe language", systemImage: "character.bubble")
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .pickerStyle(.navigationLink)

            Toggle(isOn: $preferences.translatesAutomatically) {
                Label("Translate automatically", systemImage: "wand.and.stars")
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .disabled(preferences.recipeLanguage == .dontTranslate)
        } header: {
            Text("Language")
        } footer: {
            Text(footer)
        }
        .task {
            if languages.isEmpty {
                languages = await Self.supportedLanguages()
            }
        }
    }

    private var footer: String {
        if preferences.recipeLanguage == .dontTranslate {
            return "Recipes stay in the language they were written in."
        }
        let when = preferences.translatesAutomatically
            ? "Recipes in another language are translated when you open them, once the language is downloaded."
            : "Recipes in another language show a Translate button."
        return when + " Translation happens on this device, and \"Show original\" always brings the recipe back as imported."
    }

    /// The supported languages, plus the one already chosen in case it's
    /// not listed (so the picker always has a row for it).
    private var pickableLanguages: [String] {
        if case .language(let chosen) = preferences.recipeLanguage, !languages.contains(chosen) {
            return [chosen] + languages
        }
        return languages
    }

    private static func supportedLanguages() async -> [String] {
        let supported = await LanguageAvailability().supportedLanguages
        var seen = Set<String>()
        return supported
            .map(\.minimalIdentifier)
            .filter { seen.insert($0).inserted }
            .sorted {
                RecipeLanguage.displayName(for: $0, includingRegion: true)
                    .localizedCaseInsensitiveCompare(RecipeLanguage.displayName(for: $1, includingRegion: true)) == .orderedAscending
            }
    }
}
