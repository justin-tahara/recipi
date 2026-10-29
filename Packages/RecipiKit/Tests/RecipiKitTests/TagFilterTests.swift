import Foundation
import Testing
@testable import RecipiKit

struct TagFilterTests {
    private let italian = TagFacet(name: "Italian", kind: .cuisine)
    private let japanese = TagFacet(name: "Japanese", kind: .cuisine)
    private let asian = TagFacet(name: "Asian", kind: .cuisine)
    private let dinner = TagFacet(name: "Dinner", kind: .meal)
    private let vegan = TagFacet(name: "Vegan", kind: .diet)
    private let vegetarian = TagFacet(name: "Vegetarian", kind: .diet)
    private let glutenFree = TagFacet(name: "Gluten-free", kind: .diet)
    private let quick = TagFacet(name: "Quick", kind: .trait)
    private let highProtein = TagFacet(name: "High protein", kind: .trait)
    private let weeknight = TagFacet(name: "weeknight")

    @Test func nothingSelectedMatchesEverything() {
        #expect(TagFilter().matches([]))
        #expect(TagFilter().matches([italian]))
    }

    @Test func cuisinesMatchAnyOf() {
        let filter = TagFilter(selection: [italian, japanese])
        #expect(filter.matches([italian, dinner]))
        #expect(filter.matches([japanese]))
        #expect(!filter.matches([dinner]))
    }

    @Test func kindsCombineWithAnd() {
        let filter = TagFilter(selection: [italian, dinner])
        #expect(filter.matches([italian, dinner]))
        #expect(!filter.matches([italian]))
        #expect(!filter.matches([dinner, japanese]))
    }

    @Test func dietsAndTraitsMatchAllOf() {
        let filter = TagFilter(selection: [vegan, glutenFree, quick])
        #expect(filter.matches([vegan, glutenFree, quick, dinner]))
        #expect(!filter.matches([vegan, quick]))
        #expect(!TagFilter(selection: [quick, highProtein]).matches([quick]))
    }

    @Test func plainTagsMatchAllOf() {
        let filter = TagFilter(selection: [weeknight, TagFacet(name: "pasta")])
        #expect(filter.matches([TagFacet(name: "Weeknight"), TagFacet(name: "pasta")]))
        #expect(!filter.matches([weeknight]))
    }

    @Test func groupChipsMatchTheirMembers() {
        let filter = TagFilter(selection: [asian])
        #expect(filter.matches([japanese]))
        #expect(filter.matches([TagFacet(name: "Korean", kind: .cuisine)]))
        #expect(!filter.matches([italian]))
        // "Asian" + "Italian": either.
        #expect(TagFilter(selection: [asian, italian]).matches([italian]))
    }

    @Test func vegetarianIncludesVegan() {
        #expect(TagFilter(selection: [vegetarian]).matches([vegan]))
        #expect(!TagFilter(selection: [vegan]).matches([vegetarian]))
    }

    @Test func togglingAndPruning() {
        var filter = TagFilter()
        filter.toggle(italian)
        filter.toggle(dinner)
        #expect(filter.selection == [italian, dinner])
        filter.toggle(italian)
        #expect(filter.selection == [dinner])
        filter.keep(only: [italian])
        #expect(filter.isEmpty)
    }

    @Test func sectionsAreGroupedAndOrdered() {
        let sections = TagFilterSection.sections(for: [
            weeknight, quick, TagFacet(name: "Korean", kind: .cuisine), dinner, italian, TagFacet(name: "Breakfast", kind: .meal),
            japanese, highProtein, TagFacet(name: "Apple", kind: nil), TagFacet(name: "Nonna's", kind: .cuisine),
        ])
        #expect(sections.map(\.kind) == [.cuisine, .meal, .trait, nil])
        #expect(sections.map(\.title) == ["Cuisine", "Meal", "Traits", "Tags"])
        // Groups lead, then the vocabulary's order, then the person's own.
        #expect(sections[0].chips.map(\.name) == ["Asian", "European", "Mediterranean", "Italian", "Japanese", "Korean", "Nonna's"])
        #expect(sections[1].chips.map(\.name) == ["Breakfast", "Dinner"])
        #expect(sections[2].chips.map(\.name) == ["High protein", "Quick"])
        #expect(sections[3].chips.map(\.name) == ["Apple", "weeknight"])
        #expect(sections[0].chips[0].isGroup)
        #expect(!sections[0].chips[3].isGroup)
    }

    @Test func groupChipsOnlyAppearWhenUsed() {
        let sections = TagFilterSection.sections(for: [TagFacet(name: "Mexican", kind: .cuisine)])
        #expect(sections.first?.chips.map(\.name) == ["Latin American", "Mexican"])
    }

    @Test func aGroupUsedAsATagIsListedOnce() {
        let sections = TagFilterSection.sections(for: [asian, japanese])
        #expect(sections.first?.chips.map(\.name) == ["Asian", "Japanese"])
    }
}
