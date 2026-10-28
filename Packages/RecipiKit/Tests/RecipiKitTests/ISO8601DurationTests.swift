import Testing
@testable import RecipiKit

struct ISO8601DurationTests {
    @Test(arguments: [
        ("PT15M", 900.0),
        ("PT1H30M", 5_400.0),
        ("P0DT0H20M", 1_200.0),
        ("pt45s", 45.0),
        ("P1D", 86_400.0),
        ("PT1.5H", 5_400.0),
    ])
    func parsesDurations(input: String, expected: Double) {
        #expect(ISO8601Duration.seconds(from: input) == expected)
    }

    @Test(arguments: ["", "15 minutes", "PT", "P1H", "PT20"])
    func rejectsInvalidDurations(input: String) {
        #expect(ISO8601Duration.seconds(from: input) == nil)
    }
}
