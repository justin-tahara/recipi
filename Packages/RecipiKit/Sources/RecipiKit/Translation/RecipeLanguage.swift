import Foundation
import NaturalLanguage

/// Telling which language a recipe is written in, and comparing and naming
/// languages. Languages are BCP 47 codes such as "fr", "ja" or "zh-Hans".
/// Everything here runs on the device.
public enum RecipeLanguage {
    /// Stored when a recipe's language couldn't be told, so it isn't
    /// checked again every time it opens.
    public static let undetermined = "und"

    /// The language most of `text` is in, or nil when there's too little
    /// text or the recognizer isn't sure.
    public static func detect(_ text: String, minimumConfidence: Double = 0.5) -> String? {
        // A long recipe says nothing more after the first few thousand
        // characters.
        let sample = String(text.prefix(4_000))
        guard sample.contains(where: \.isLetter) else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let best = recognizer.languageHypotheses(withMaximum: 1).max(by: { $0.value < $1.value }),
              best.key != .undetermined,
              best.value >= minimumConfidence else {
            return nil
        }
        return best.key.rawValue
    }

    /// The language of a recipe's title, summary, headings, ingredients and
    /// steps together.
    public static func detect(_ text: RecipeText) -> String? {
        detect(text.languageSample)
    }

    /// The language the device is set to, e.g. "en" or "pt-BR".
    public static var deviceLanguage: String {
        if let preferred = Locale.preferredLanguages.first {
            return Locale.Language(identifier: preferred).minimalIdentifier
        }
        return Locale.current.language.minimalIdentifier
    }

    /// True when `first` and `second` are the same language for reading,
    /// ignoring the region: "en" and "en-GB" are, "zh-Hans" and "zh-Hant"
    /// (different scripts) aren't.
    public static func isSame(_ first: String, as second: String) -> Bool {
        let one = Locale.Language(identifier: first)
        let other = Locale.Language(identifier: second)
        guard let code = one.languageCode, code == other.languageCode else { return false }
        let oneScript = Locale.Language(identifier: one.maximalIdentifier).script
        let otherScript = Locale.Language(identifier: other.maximalIdentifier).script
        return oneScript == otherScript
    }

    /// The language's name for people, e.g. "French". The region is left
    /// out unless `includingRegion` ("English (United Kingdom)"); a script
    /// that tells two written forms apart is kept ("Chinese, Simplified").
    public static func displayName(for code: String, includingRegion: Bool = false, locale: Locale = .current) -> String {
        let language = Locale.Language(identifier: code)
        // A four-letter subtag is a script, as in "zh-Hant".
        let namesScript = code.split(whereSeparator: { $0 == "-" || $0 == "_" }).dropFirst()
            .contains { $0.count == 4 && $0.allSatisfy(\.isLetter) }
        let name: String?
        if includingRegion || namesScript {
            name = locale.localizedString(forIdentifier: code)
        } else if let languageCode = language.languageCode {
            name = locale.localizedString(forLanguageCode: languageCode.identifier)
        } else {
            name = nil
        }
        return name ?? code
    }
}

/// Which language recipes are shown in. Stored as text: "device", "none",
/// or a language code.
public enum RecipeLanguageChoice: Hashable, Sendable, RawRepresentable, PreferenceValue {
    /// Whatever language the device is set to. The default.
    case deviceLanguage
    /// A language the person picked, as a BCP 47 code.
    case language(String)
    /// Leave every recipe in the language it was written in.
    case dontTranslate

    public init?(rawValue: String) {
        switch rawValue {
        case "device": self = .deviceLanguage
        case "none": self = .dontTranslate
        case "": return nil
        default: self = .language(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .deviceLanguage: "device"
        case .dontTranslate: "none"
        case .language(let code): code
        }
    }

    /// The language to translate recipes into, or nil for don't translate.
    public func targetLanguage(deviceLanguage: String = RecipeLanguage.deviceLanguage) -> String? {
        switch self {
        case .deviceLanguage: deviceLanguage
        case .language(let code): code
        case .dontTranslate: nil
        }
    }
}
