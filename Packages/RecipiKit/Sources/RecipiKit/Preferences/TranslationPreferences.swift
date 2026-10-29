import Foundation

extension PreferenceKeys {
    /// The language recipes are translated into: the device language unless
    /// the person picks another, or none. See `RecipeLanguageChoice`.
    public static let recipeLanguage = PreferenceKey<RecipeLanguageChoice>(
        "translation.recipeLanguage",
        default: .deviceLanguage
    )

    /// Translate a recipe in another language as soon as it opens, when the
    /// language is already downloaded. Off by default: the recipe shows a
    /// Translate button instead.
    public static let translateAutomatically = PreferenceKey<Bool>("translation.automatic", default: false)
}

extension Preferences {
    /// See `PreferenceKeys.recipeLanguage`.
    public var recipeLanguage: RecipeLanguageChoice {
        get { self[PreferenceKeys.recipeLanguage] }
        set { self[PreferenceKeys.recipeLanguage] = newValue }
    }

    /// See `PreferenceKeys.translateAutomatically`.
    public var translatesAutomatically: Bool {
        get { self[PreferenceKeys.translateAutomatically] }
        set { self[PreferenceKeys.translateAutomatically] = newValue }
    }
}
