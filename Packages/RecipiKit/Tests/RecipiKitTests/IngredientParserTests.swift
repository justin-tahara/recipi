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

    @Test func splitsTheAmountFromTheRest() {
        let asWritten = IngredientParser.parse("1 1/2 cups milk").scaledParts(by: 1)
        #expect(asWritten.amount == "1 1/2")
        #expect(asWritten.rest == " cups milk")

        let doubled = IngredientParser.parse("2-3 cloves garlic").scaledParts(by: 2)
        #expect(doubled.amount == "4–6")
        #expect(doubled.rest == " cloves garlic")

        let noAmount = IngredientParser.parse("Salt to taste").scaledParts(by: 2)
        #expect(noAmount.lead == "")
        #expect(noAmount.amount == "")
        #expect(noAmount.rest == "Salt to taste")
    }
}

struct DecimalCommaTests {
    @Test(arguments: [
        ("1,5 kg Mehl", 1.5, "kg"),
        ("0,5 l Milch", 0.5, "l"),
        ("2,25 kg Kartoffeln", 2.25, "kg"),
        ("1,5kg Mehl", 1.5, "kg"),
        ("12,5 g Hefe", 12.5, "g"),
    ])
    func readsADecimalComma(line: String, quantity: Double, unit: String) {
        let parsed = IngredientParser.parse(line)
        #expect(parsed.quantity == quantity)
        #expect(parsed.unit == unit)
    }

    @Test(arguments: [
        ("1,000 g sugar", 1000.0),
        ("12,500 g flour", 12500.0),
        ("1,250,000 g", 1_250_000.0),
        ("1,000.5 g", 1000.5),
    ])
    func readsThreeDigitsAfterACommaAsThousands(line: String, quantity: Double) {
        let parsed = IngredientParser.parse(line)
        #expect(parsed.quantity == quantity)
        #expect(parsed.unit == "g")
    }

    @Test func aCommaAndASpaceIsAList() {
        let parsed = IngredientParser.parse("1, 2 or 3 eggs")
        #expect(parsed.quantity == 1)
        #expect(parsed.upperQuantity == nil)
        #expect(parsed.remainder == ", 2 or 3 eggs")
    }

    @Test func otherCommasEndTheNumber() {
        #expect(IngredientParser.parse("1,0000 g").quantity == 1)
        #expect(IngredientParser.parse("1,5,6").quantity == 1)
        #expect(IngredientParser.parse("2 cups flour, sifted").quantity == 2)
    }

    @Test func readsDecimalCommaRanges() {
        let parsed = IngredientParser.parse("1,5-2 kg Rindfleisch")
        #expect(parsed.quantity == 1.5)
        #expect(parsed.upperQuantity == 2)
        #expect(parsed.unit == "kg")
    }

    @Test func scalesDecimalCommas() {
        #expect(IngredientParser.parse("1,5 kg Mehl").scaled(by: 2) == "3 kg Mehl")
        #expect(IngredientParser.parse("0,5 l Milch").scaled(by: 3) == "1½ l Milch")
        #expect(IngredientParser.parse("1,000 g sugar").scaled(by: 0.5) == "500 g sugar")
        #expect(IngredientParser.parse("1,5 kg Mehl").scaled(by: 1) == "1,5 kg Mehl")
    }

    @Test func convertsDecimalCommas() {
        #expect(IngredientParser.parse("0,5 l Milch").display(scaledBy: 1, in: .us) == "2 cups Milch")
    }
}

/// Japanese lines that put the amount after the item.
struct AmountAfterItemTests {
    @Test(arguments: [
        ("砂糖 大さじ2", 2.0, "tbsp"),
        ("醤油 大さじ1と1/2", 1.5, "tbsp"),
        ("砂糖 小さじ1", 1.0, "tsp"),
        ("醤油 大さじ 1", 1.0, "tbsp"),
        ("卵 2個", 2.0, "個"),
        ("玉ねぎ 1/2個", 0.5, "個"),
        ("長ねぎ 1本", 1.0, "本"),
        ("海苔 2枚", 2.0, "枚"),
        ("しょうが 1片", 1.0, "片"),
        ("水 200ml", 200.0, "ml"),
        ("水 200cc", 200.0, "ml"),
        ("鶏もも肉 300g", 300.0, "g"),
        ("小麦粉 1kg", 1.0, "kg"),
        ("牛乳 カップ1", 1.0, "カップ"),
        ("牛乳 1カップ", 1.0, "カップ"),
        ("砂糖 大さじ２", 2.0, "tbsp"),
        ("水 ２００ｍｌ", 200.0, "ml"),
    ])
    func readsTheAmountAfterTheItem(line: String, quantity: Double, unit: String) {
        let parsed = IngredientParser.parse(line)
        #expect(parsed.quantity == quantity)
        #expect(parsed.unit == unit)
        #expect(!parsed.lead.isEmpty)
    }

    @Test func readsRanges() {
        let parsed = IngredientParser.parse("にんにく 1〜2片")
        #expect(parsed.quantity == 1)
        #expect(parsed.upperQuantity == 2)
        #expect(parsed.scaled(by: 2) == "にんにく 2–4片")
    }

    @Test func scalingKeepsTheLinesOrder() {
        #expect(IngredientParser.parse("砂糖 大さじ2").scaled(by: 2) == "砂糖 大さじ4")
        #expect(IngredientParser.parse("醤油 大さじ1と1/2").scaled(by: 2) == "醤油 大さじ3")
        #expect(IngredientParser.parse("卵 2個").scaled(by: 1.5) == "卵 3個")
        #expect(IngredientParser.parse("水 200ml").scaled(by: 0.5) == "水 100ml")
        #expect(IngredientParser.parse("醤油 大さじ1と1/2").scaled(by: 1) == "醤油 大さじ1と1/2")
    }

    @Test func splitsAroundTheAmount() {
        let doubled = IngredientParser.parse("砂糖 大さじ2").scaledParts(by: 2)
        #expect(doubled.lead == "砂糖 大さじ")
        #expect(doubled.amount == "4")
        #expect(doubled.rest == "")

        let asWritten = IngredientParser.parse("卵 2個").scaledParts(by: 1)
        #expect(asWritten.lead == "卵 ")
        #expect(asWritten.amount == "2")
        #expect(asWritten.rest == "個")
    }

    @Test(arguments: [
        ("砂糖 大さじ2", MeasurementPreference.metric, "砂糖 30 ml"),
        ("砂糖 大さじ2", MeasurementPreference.us, "砂糖 大さじ2"),
        ("水 200ml", MeasurementPreference.us, "水 ¾ cup"),
        ("鶏もも肉 300g", MeasurementPreference.us, "鶏もも肉 10½ oz"),
        ("牛乳 カップ1", MeasurementPreference.us, "牛乳 カップ1"),
        ("牛乳 カップ1", MeasurementPreference.metric, "牛乳 カップ1"),
        ("卵 2個", MeasurementPreference.metric, "卵 2個"),
    ])
    func convertsUnits(line: String, preference: MeasurementPreference, expected: String) {
        #expect(IngredientParser.parse(line).display(scaledBy: 1, in: preference) == expected)
    }

    @Test(arguments: [
        "Salt 1 tsp",
        "Juice of 1 lemon",
        "ご飯 2杯分",
        "砂糖 大さじ2（お好みで）",
        "塩 少々",
        "大さじ2",
    ])
    func leavesOtherLinesWithoutAnAmount(line: String) {
        #expect(IngredientParser.parse(line).quantity == nil)
    }

    @Test func amountsFirstStillWin() {
        let parsed = IngredientParser.parse("2 cups flour")
        #expect(parsed.lead == "")
        #expect(parsed.quantity == 2)
        #expect(IngredientParser.parse("1 大さじ").unit == "tbsp")
    }

    @Test func scalesToWhatYouHave() throws {
        let chicken = IngredientParser.parse("鶏もも肉 300g")
        #expect(IngredientScaling.factor(for: chicken, have: 600, unit: nil) == 2)
        let fromKilograms = try #require(IngredientScaling.factor(for: chicken, have: 0.9, unit: "kg"))
        #expect(abs(fromKilograms - 3) < 0.001)
        #expect(IngredientScaling.unitChoices(for: chicken) == ["g", "kg", "oz", "lb"])
        #expect(IngredientScaling.unitChoices(for: IngredientParser.parse("砂糖 大さじ2")).first == "tbsp")
        #expect(IngredientScaling.unitChoices(for: IngredientParser.parse("卵 2個")).isEmpty)
        #expect(IngredientScaling.factor(for: IngredientParser.parse("卵 2個"), have: 6, unit: nil) == 3)
    }

    @Test func namesTheItem() {
        #expect(IngredientScaling.itemName(of: IngredientParser.parse("砂糖 大さじ2")) == "砂糖")
        #expect(IngredientScaling.itemName(of: IngredientParser.parse("卵 2個")) == "卵")
        #expect(IngredientScaling.itemName(of: IngredientParser.parse("水 200ml")) == "水")
    }

    @Test func editorKeepsTheLineWhole() {
        #expect(IngredientParts(parsing: "砂糖 大さじ2") == IngredientParts(name: "砂糖 大さじ2"))
    }

    @Test func readsTheJapaneseFixture() throws {
        let draft = try RecipeImporter.parse(html: Fixture.html("lang-ja"), sourceURL: nil)
        let amounts = draft.ingredients.map { IngredientParser.parse($0.text).quantity }
        // "ご飯 2杯分" (bowls' worth) isn't a unit we read.
        #expect(amounts == [300, 0.5, 3, 150, 2, 2, 1, nil])
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
