import Foundation

/// What a tag is about. Tags from the built-in vocabulary have a kind, and
/// a person can give one to any tag; tags without one are plain tags.
public enum TagKind: String, CaseIterable, Sendable, Identifiable {
    case cuisine
    case meal
    case diet
    case trait

    public var id: String { rawValue }

    /// The heading the Library and tag screen show for this kind.
    public var title: String {
        switch self {
        case .cuisine: "Cuisine"
        case .meal: "Meal"
        case .diet: "Diet"
        case .trait: "Traits"
        }
    }

    /// True when a recipe usually has one of these, so picking two filter
    /// chips of this kind means "either" (Italian or Japanese). For the
    /// other kinds, and plain tags, two chips mean "both" (vegan and
    /// gluten-free).
    public var filtersAsAnyOf: Bool {
        switch self {
        case .cuisine, .meal: true
        case .diet, .trait: false
        }
    }
}
