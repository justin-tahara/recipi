import XCTest

/// Walks the main path once: import a recipe from a link, open it, scale
/// it, cook it and add it to the grocery list. The app runs with
/// `-ui-testing`, so it starts with an empty in-memory library and the
/// import is served from a fixture page, never the network.
final class SmokeTests: XCTestCase {
    /// Matches `FixturePages.lemonSpaghettiURL` in the app target.
    private let fixtureURL = "https://fixtures.recipi.test/lemon-spaghetti"
    private let timeout: TimeInterval = 10

    @MainActor
    func testImportScaleCookAndShop() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        // Import from the empty library.
        let importButton = app.buttons["Import from link"].firstMatch
        XCTAssertTrue(importButton.waitForExistence(timeout: timeout))
        importButton.tap()

        let linkField = app.textFields.firstMatch
        XCTAssertTrue(linkField.waitForExistence(timeout: timeout))
        linkField.tap()
        linkField.typeText(fixtureURL)
        app.buttons["Import recipe"].firstMatch.tap()

        // The preview shows; Save turns on once the photo lookup is done.
        let save = app.buttons["Save recipe"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: timeout))
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        wait(for: [enabled], timeout: timeout)
        save.tap()

        // The sheet closes and the recipe is in the library.
        let row = element("library.recipe", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        XCTAssertTrue(row.label.contains("Lemon Garlic Spaghetti"))
        row.tap()

        // Serves 4; one more scales 400 g to 500 g.
        let servings = element("recipe.servings", in: app)
        XCTAssertTrue(servings.waitForExistence(timeout: timeout))
        XCTAssertEqual(servings.value as? String, "4")
        // The stepper is one accessible element; tap its plus half.
        servings.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        XCTAssertEqual(servings.value as? String, "5")
        // Ingredient rows with an amount are buttons, so match any element.
        XCTAssertTrue(labeled("500 g spaghetti", in: app).waitForExistence(timeout: timeout))

        // Cooking mode: two steps, then finish.
        app.buttons["Start cooking"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Boil the spaghetti in salted water until al dente."].waitForExistence(timeout: timeout))
        let next = app.buttons["cooking.next"]
        XCTAssertTrue(next.waitForExistence(timeout: timeout))
        next.tap()
        XCTAssertTrue(next.label.hasPrefix("Finish"), "Expected the last step, got \(next.label)")
        next.tap()

        // Finishing offers to log the cook; skipping closes cooking mode.
        let skip = app.buttons["Skip"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: timeout))
        skip.tap()
        XCTAssertTrue(next.waitForNonExistence(timeout: timeout))

        // Add the scaled ingredients to the grocery list.
        app.navigationBars.buttons["More"].firstMatch.tap()
        let addToList = app.buttons["Add to grocery list"].firstMatch
        XCTAssertTrue(addToList.waitForExistence(timeout: timeout))
        addToList.tap()
        XCTAssertTrue(app.staticTexts["Added 4 items to Groceries"].waitForExistence(timeout: timeout))

        app.tabBars.buttons["Groceries"].tap()
        let items = app.buttons.matching(identifier: "grocery.item")
        XCTAssertTrue(items.firstMatch.waitForExistence(timeout: timeout))
        XCTAssertEqual(items.count, 4)
        let spaghetti = items.matching(NSPredicate(format: "label CONTAINS %@", "500 g spaghetti")).firstMatch
        XCTAssertTrue(spaghetti.exists)
    }

    /// Finds an element by its label whatever its accessibility type.
    @MainActor
    private func labeled(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Finds an element by identifier whatever its accessibility type.
    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
