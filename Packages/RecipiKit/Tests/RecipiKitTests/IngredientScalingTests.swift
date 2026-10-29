import Testing
@testable import RecipiKit

struct IngredientScalingTests {
    private func factor(_ line: String, have amount: Double, _ unit: String? = nil) -> Double? {
        IngredientScaling.factor(for: IngredientParser.parse(line), have: amount, unit: unit)
    }

    @Test func sameUnitDividesTheAmounts() {
        #expect(factor("1 lb chicken thighs", have: 2) == 2)
        #expect(factor("1 lb chicken thighs", have: 2, "lb") == 2)
        #expect(factor("4 cups stock", have: 1, "cup") == 0.25)
    }

    @Test func convertsBetweenUnitsOfTheSameKind() throws {
        let fromGrams = try #require(factor("1 lb chicken", have: 907.184, "g"))
        #expect(abs(fromGrams - 2) < 0.001)
        let fromCups = try #require(factor("250 ml milk", have: 2, "cup"))
        #expect(abs(fromCups - 1.8927) < 0.001)
    }

    @Test func refusesUnitsThatMeasureDifferentThings() {
        #expect(factor("1 cup flour", have: 200, "g") == nil)
    }

    @Test func worksForCountsAndRanges() {
        #expect(factor("3 eggs", have: 6) == 2)
        #expect(factor("2-3 cloves garlic", have: 4) == 2)
    }

    @Test func linesWithoutAmountsCantScale() {
        #expect(factor("Salt to taste", have: 2) == nil)
        #expect(factor("2 lb chicken", have: 0) == nil)
    }

    @Test func offersUnitsOfTheSameKindWithTheLinesOwnFirst() {
        #expect(IngredientScaling.unitChoices(for: IngredientParser.parse("1 lb chicken")) == ["lb", "g", "kg", "oz"])
        #expect(IngredientScaling.unitChoices(for: IngredientParser.parse("2 cups milk")).first == "cup")
        #expect(IngredientScaling.unitChoices(for: IngredientParser.parse("2 cups milk")).contains("ml"))
        #expect(IngredientScaling.unitChoices(for: IngredientParser.parse("3 eggs")).isEmpty)
    }

    @Test func namesTheIngredient() {
        #expect(IngredientScaling.itemName(of: IngredientParser.parse("1 lb chicken thighs, skin on")) == "chicken thighs")
        #expect(IngredientScaling.itemName(of: IngredientParser.parse("2 cloves garlic")) == "cloves garlic")
        #expect(IngredientScaling.itemName(of: IngredientParser.parse("3 eggs")) == "eggs")
    }

    @Test func labelsMultipliers() {
        #expect(IngredientScaling.multiplierLabel(2) == "×2")
        #expect(IngredientScaling.multiplierLabel(0.5) == "×½")
        #expect(IngredientScaling.multiplierLabel(1.5) == "×1½")
    }
}
