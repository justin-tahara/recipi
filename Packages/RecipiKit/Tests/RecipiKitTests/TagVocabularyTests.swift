import Foundation
import Testing
@testable import RecipiKit

struct TagVocabularyTests {
    @Test(arguments: [
        ("Italian", "Italian"),
        ("italiano", "Italian"),
        ("Italienne", "Italian"),
        ("Italian Recipes", "Italian"),
        ("japonais", "Japanese"),
        ("和食", "Japanese"),
        ("Japanese food", "Japanese"),
        ("Koreanisch", "Korean"),
        ("中華料理", "Chinese"),
        ("Thaï", "Thai"),
        ("Tex-Mex", "Mexican"),
        ("Middle Eastern", "Middle Eastern"),
        ("vegetariano", "Vegetarian"),
        ("Végétarien", "Vegetarian"),
        ("Gluten Free", "Gluten-free"),
        ("gluten-free", "Gluten-free"),
        ("sans gluten", "Gluten-free"),
        ("Plant-Based", "Vegan"),
        ("Main Course", "Dinner"),
        ("Plat principal", "Dinner"),
        ("Side Dish", "Side"),
        ("Appetizers", "Snack"),
        ("Desserts", "Dessert"),
        ("Cocktails", "Drink"),
        ("Brunch", "Breakfast"),
        ("High-Protein", "High protein"),
        ("Low Calorie", "Light"),
        ("30-minute meals", "Quick"),
        ("Quick & Easy", "Quick"),
        ("Asian", "Asian"),
        ("VegetarianDiet", "Vegetarian"),
    ])
    func synonymsMapToOneTerm(value: String, expected: String) throws {
        let term = try #require(TagVocabulary.term(matching: value))
        #expect(term.name == expected)
    }

    @Test(arguments: ["French toast", "Greek yogurt", "Thai basil", "light brown sugar", "sweet potato", "pancakes", "", "  "])
    func phrasesThatOnlyMentionATermDontMatch(value: String) {
        #expect(TagVocabulary.terms(in: value) == nil)
    }

    @Test func phrasesMadeOfTermsGiveEachTerm() throws {
        let terms = try #require(TagVocabulary.terms(in: "Quick vegetarian dinner recipes"))
        #expect(terms.map(\.name) == ["Quick", "Vegetarian", "Dinner"])
        #expect(TagVocabulary.term(matching: "Quick vegetarian dinner") == nil)
    }

    @Test func kindsAreRight() {
        #expect(TagVocabulary.term(named: "Italian")?.kind == .cuisine)
        #expect(TagVocabulary.term(named: "dinner")?.kind == .meal)
        #expect(TagVocabulary.term(named: "VEGAN")?.kind == .diet)
        #expect(TagVocabulary.term(named: "Quick")?.kind == .trait)
        #expect(TagVocabulary.term(named: "italiano") == nil, "term(named:) is exact; synonyms go through term(matching:)")
    }

    @Test func groupsMatchTheirMembers() {
        #expect(TagVocabulary.chip(named: "Asian", matchesTagNamed: "Japanese"))
        #expect(TagVocabulary.chip(named: "Asian", matchesTagNamed: "korean"))
        #expect(TagVocabulary.chip(named: "Asian", matchesTagNamed: "和食"))
        #expect(TagVocabulary.chip(named: "Asian", matchesTagNamed: "Asian"))
        #expect(!TagVocabulary.chip(named: "Asian", matchesTagNamed: "Italian"))
        #expect(TagVocabulary.chip(named: "Mediterranean", matchesTagNamed: "Greek"))
        #expect(TagVocabulary.chip(named: "European", matchesTagNamed: "Italian"))
        // A member doesn't match its group.
        #expect(!TagVocabulary.chip(named: "Japanese", matchesTagNamed: "Asian"))
    }

    @Test func dietsCoverStricterDiets() {
        #expect(TagVocabulary.chip(named: "Vegetarian", matchesTagNamed: "Vegan"))
        #expect(TagVocabulary.chip(named: "Dairy-free", matchesTagNamed: "Vegan"))
        #expect(!TagVocabulary.chip(named: "Vegan", matchesTagNamed: "Vegetarian"))
    }

    @Test func plainTagsMatchByName() {
        #expect(TagVocabulary.chip(named: "Weeknight", matchesTagNamed: "weeknight"))
        #expect(!TagVocabulary.chip(named: "Weeknight", matchesTagNamed: "Weekend"))
        #expect(TagVocabulary.chip(named: "Italian", matchesTagNamed: "italiano"))
    }

    @Test func normalizingIgnoresCaseAccentsAndPunctuation() {
        #expect(TagVocabulary.normalized("  Gluten-Free! ") == "gluten free")
        #expect(TagVocabulary.normalized("Hors d’Oeuvres") == "hors doeuvres")
        #expect(TagVocabulary.normalized("Végétarien") == "vegetarien")
    }

    /// Two terms claiming the same word would make one of them unreachable.
    @Test func noWordBelongsToTwoTerms() {
        var owner: [String: String] = [:]
        for term in TagVocabulary.terms {
            for word in [term.name] + term.synonyms {
                let key = TagVocabulary.normalized(word)
                #expect(!key.isEmpty, "\(word) normalizes to nothing")
                if let existing = owner[key] {
                    #expect(existing == term.name, "\(word) is in both \(existing) and \(term.name)")
                }
                owner[key] = term.name
                #expect(!TagVocabulary.fillerWords.contains(key), "\(word) is also a filler word")
            }
        }
    }

    @Test func groupMembersAreTerms() {
        for term in TagVocabulary.terms {
            for member in term.includes {
                #expect(TagVocabulary.term(named: member) != nil, "\(term.name) includes unknown \(member)")
            }
        }
    }

    @Test func everyKindHasTerms() {
        for kind in TagKind.allCases {
            #expect(!TagVocabulary.terms(of: kind).isEmpty)
        }
        let meals = TagVocabulary.terms(of: .meal).map(\.name)
        #expect(meals == ["Breakfast", "Lunch", "Dinner", "Side", "Snack", "Dessert", "Drink"])
        let diets = TagVocabulary.terms(of: .diet).map(\.name)
        #expect(diets == ["Vegetarian", "Vegan", "Gluten-free", "Dairy-free"])
        let traits = TagVocabulary.terms(of: .trait).map(\.name)
        #expect(traits == ["High protein", "Light", "Quick"])
    }
}
