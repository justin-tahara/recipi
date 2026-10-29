import Foundation
import Testing
@testable import RecipiKit

struct UnitConversionTests {
    private func show(_ line: String, scale: Double = 1, _ preference: MeasurementPreference) -> String {
        IngredientParser.parse(line).display(scaledBy: scale, in: preference)
    }

    @Test(arguments: [
        ("1 cup milk", "240 ml milk"),
        ("4 oz butter", "115 g butter"),
        ("1 lb chicken thighs", "455 g chicken thighs"),
        ("3 lb potatoes", "1.4 kg potatoes"),
        ("1 tsp salt", "5 ml salt"),
        ("2 Tbsp. olive oil", "30 ml olive oil"),
        ("8 fl oz cream", "240 ml cream"),
        ("1-2 cups stock", "240–470 ml stock"),
    ])
    func convertsUSToMetric(line: String, expected: String) {
        #expect(show(line, .metric) == expected)
    }

    @Test(arguments: [
        ("250 g flour", "8¾ oz flour"),
        ("350g flour", "12¼ oz flour"),
        ("500 ml stock", "2 cups stock"),
        ("15 ml soy sauce", "1 tbsp soy sauce"),
        ("5 ml vanilla", "1 tsp vanilla"),
        ("1 kg potatoes", "2¼ lb potatoes"),
        ("60 ml lemon juice", "¼ cup lemon juice"),
    ])
    func convertsMetricToUS(line: String, expected: String) {
        #expect(show(line, .us) == expected)
    }

    @Test func linesAlreadyInTheChosenSystemOnlyScale() {
        #expect(show("2 cups milk", .us) == "2 cups milk")
        #expect(show("200 g sugar", .metric) == "200 g sugar")
        #expect(show("200 g sugar", scale: 2, .metric) == "400 g sugar")
    }

    @Test func countUnitsAndLinesWithoutAmountsStayAsWritten() {
        #expect(show("2 cloves garlic", .metric) == "2 cloves garlic")
        #expect(show("1 (14 oz) can tomatoes", .metric) == "1 (14 oz) can tomatoes")
        #expect(show("Salt to taste", .us) == "Salt to taste")
        #expect(show("3 eggs", .metric) == "3 eggs")
    }

    @Test func asWrittenKeepsTheOriginalText() {
        #expect(show("1 1/2 cups milk", .asWritten) == "1 1/2 cups milk")
        #expect(show("8 fl oz cream", .asWritten) == "8 fl oz cream")
    }

    @Test func scalesBeforeConverting() {
        #expect(show("1 cup milk", scale: 2, .metric) == "470 ml milk")
        #expect(show("100 g butter", scale: 0.5, .us) == "1¾ oz butter")
    }

    @Test func splitsAmountFromTheRest() {
        let parts = IngredientParser.parse("4 oz butter, softened").displayParts(scaledBy: 1, in: .metric)
        #expect(parts.amount == "115")
        #expect(parts.rest == " g butter, softened")
    }

    @Test func deviceDefaultFollowsTheLocale() {
        #expect(MeasurementPreference.deviceDefault(for: Locale(identifier: "en_US")) == .us)
        #expect(MeasurementPreference.deviceDefault(for: Locale(identifier: "en_GB")) == .metric)
        #expect(MeasurementPreference.deviceDefault(for: Locale(identifier: "ja_JP")) == .metric)
    }
}

struct TemperatureConverterTests {
    @Test(arguments: [
        ("Bake at 350°F for 20 minutes.", "Bake at 175°C for 20 minutes."),
        ("Preheat the oven to 425 degrees F.", "Preheat the oven to 220°C."),
        ("Roast at 400F until golden.", "Roast at 205°C until golden."),
        ("Cook to 165 °F inside.", "Cook to 74°C inside."),
        ("Simmer for 10 minutes.", "Simmer for 10 minutes."),
    ])
    func convertsToCelsius(text: String, expected: String) {
        #expect(TemperatureConverter.convert(text, to: .metric) == expected)
    }

    @Test(arguments: [
        ("Heat the oven to 180°C.", "Heat the oven to 350°F."),
        ("Bake at 200 degrees Celsius.", "Bake at 400°F."),
        ("Add 2 C water and stir.", "Add 2 C water and stir."),
    ])
    func convertsToFahrenheit(text: String, expected: String) {
        #expect(TemperatureConverter.convert(text, to: .us) == expected)
    }

    @Test func leavesTemperaturesAloneWhenAsWrittenOrAlreadyRight() {
        #expect(TemperatureConverter.convert("Bake at 350°F.", to: .asWritten) == "Bake at 350°F.")
        #expect(TemperatureConverter.convert("Bake at 350°F.", to: .us) == "Bake at 350°F.")
        #expect(TemperatureConverter.convert("Bake at 180°C.", to: .metric) == "Bake at 180°C.")
    }
}
