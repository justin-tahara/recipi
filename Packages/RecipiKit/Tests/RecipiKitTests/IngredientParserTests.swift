import Testing
@testable import RecipiKit

struct IngredientParserTests {
    @Test(arguments: [
        ("2 cups flour", 2.0),
        ("1.5 tsp salt", 1.5),
        ("1/2 cup sugar", 0.5),
        ("1 1/2 cups milk", 1.5),
        ("½ onion", 0.5),
        ("1½ cups stock", 1.5),
        ("1 ¼ cups water", 1.25),
        ("350g flour", 350.0),
    ])
    func readsLeadingAmount(line: String, expected: Double) {
        #expect(IngredientParser.parse(line).quantity == expected)
    }

    @Test func linesWithoutAmountsAreLeftAlone() {
        let parsed = IngredientParser.parse("Salt and pepper to taste")
        #expect(parsed.quantity == nil)
        #expect(parsed.scaled(by: 2) == "Salt and pepper to taste")
    }

    @Test func readsRanges() {
        let parsed = IngredientParser.parse("2-3 cloves garlic")
        #expect(parsed.quantity == 2)
        #expect(parsed.upperQuantity == 3)
        #expect(parsed.unit == "clove")
        #expect(parsed.scaled(by: 2) == "4–6 cloves garlic")
    }

    @Test func recognisesUnits() {
        #expect(IngredientParser.parse("2 Tablespoons butter").unit == "tbsp")
        #expect(IngredientParser.parse("1 T butter").unit == "tbsp")
        #expect(IngredientParser.parse("1 t salt").unit == "tsp")
        #expect(IngredientParser.parse("3 eggs").unit == nil)
    }

    @Test func scalingKeepsTheRestOfTheLine() {
        #expect(IngredientParser.parse("1 (14 oz) can tomatoes").scaled(by: 2) == "2 (14 oz) can tomatoes")
        #expect(IngredientParser.parse("350g flour").scaled(by: 0.5) == "175g flour")
        #expect(IngredientParser.parse("1 cup rice").scaled(by: 1.5) == "1½ cup rice")
        #expect(IngredientParser.parse("2 cups milk").scaled(by: 1.0 / 3) == "⅔ cups milk")
    }

    @Test func scalingByOneReturnsTheOriginal() {
        #expect(IngredientParser.parse("1 1/2 cups milk").scaled(by: 1) == "1 1/2 cups milk")
    }
}

struct QuantityFormatterTests {
    @Test(arguments: [
        (0.5, "½"),
        (2.25, "2¼"),
        (0.999, "1"),
        (3.0, "3"),
        (2.1, "2.1"),
        (30.0, "30"),
        (137.4, "137"),
    ])
    func formats(value: Double, expected: String) {
        #expect(QuantityFormatter.string(from: value) == expected)
    }
}
