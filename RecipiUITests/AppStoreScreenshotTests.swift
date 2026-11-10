import XCTest

/// Takes the App Store screenshots. The app starts with a sample library
/// (`-ui-testing -sample-library`, see `SampleLibrary` in the app target),
/// and each main screen is saved as a screenshot attachment kept in the
/// result bundle, named in the order they go on the listing.
///
/// Not run on pull requests. `.github/workflows/app-store-screenshots.yml`
/// runs it on a 6.9-inch iPhone with a clean status bar and keeps the
/// result bundle; export the PNGs with
/// `xcrun xcresulttool export attachments --path <bundle> --output-path <dir>`.
final class AppStoreScreenshotTests: XCTestCase {
    /// Matches `FixturePages.sheetPanGnocchiURL` in the app target.
    private let importURL = "https://cooking.example/sheet-pan-gnocchi"
    private let featuredRecipe = "Miso Butter Salmon"
    private let timeout: TimeInterval = 15

    @MainActor
    func testTakeAppStoreScreenshots() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-sample-library"]
        app.launch()

        // The library, with its tags and photos.
        let rows = app.descendants(matching: .any).matching(identifier: "library.recipe")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: timeout))
        XCTAssertGreaterThanOrEqual(rows.count, 4)
        saveScreenshot("01-Library")

        // The import preview, taken now so the library stays as seeded:
        // Cancel saves nothing.
        try showImportPreview(app)
        saveScreenshot("06-Import-preview")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Save recipe"].firstMatch.waitForNonExistence(timeout: timeout))

        // A recipe page.
        let featured = rows.matching(NSPredicate(format: "label CONTAINS %@", featuredRecipe)).firstMatch
        XCTAssertTrue(featured.waitForExistence(timeout: timeout))
        featured.tap()
        let servings = element("recipe.servings", in: app)
        XCTAssertTrue(servings.waitForExistence(timeout: timeout))
        saveScreenshot("02-Recipe")

        // Scaled from 2 servings to 4, in metric.
        XCTAssertEqual(servings.value as? String, "2")
        // The stepper is one accessible element; tap its plus half.
        let plus = servings.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        plus.tap()
        plus.tap()
        XCTAssertEqual(servings.value as? String, "4")
        app.buttons["Units"].firstMatch.tap()
        let metric = labeled("Metric", in: app)
        XCTAssertTrue(metric.waitForExistence(timeout: timeout))
        metric.tap()
        XCTAssertTrue(app.buttons["Reset scale"].firstMatch.waitForExistence(timeout: timeout))
        // Scroll so the properties and the scaled ingredients share the
        // screen. Holding at the end stops the scroll from coasting on.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.36))
        from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.5)
        saveScreenshot("03-Scaling-and-units")

        // Cooking mode, on the second step.
        app.buttons["Start cooking"].firstMatch.tap()
        let next = app.buttons["cooking.next"]
        XCTAssertTrue(next.waitForExistence(timeout: timeout))
        next.tap()
        let progress = app.descendants(matching: .any)["Progress"].firstMatch
        let onStepTwo = expectation(for: NSPredicate(format: "value == %@", "Step 2 of 5"), evaluatedWith: progress)
        wait(for: [onStepTwo], timeout: timeout)
        saveScreenshot("04-Cooking-mode")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(next.waitForNonExistence(timeout: timeout))

        // The grocery list, some of it already in the cart.
        app.tabBars.buttons["Groceries"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "grocery.item").firstMatch.waitForExistence(timeout: timeout))
        saveScreenshot("05-Groceries")
    }

    /// Imports the screenshot fixture page and waits for its photos.
    @MainActor
    private func showImportPreview(_ app: XCUIApplication) throws {
        app.buttons["Add recipe"].firstMatch.tap()
        let importItem = app.buttons["Import from link"].firstMatch
        XCTAssertTrue(importItem.waitForExistence(timeout: timeout))
        importItem.tap()

        let linkField = app.textFields.firstMatch
        XCTAssertTrue(linkField.waitForExistence(timeout: timeout))
        linkField.tap()
        linkField.typeText(importURL)
        // Keystrokes can go missing on a slow runner. Type it again if so.
        if linkField.value as? String != importURL {
            let clear = app.buttons["Clear link"].firstMatch
            if clear.exists { clear.tap() }
            linkField.tap()
            linkField.typeText(importURL)
        }
        XCTAssertEqual(linkField.value as? String, importURL)
        // Return imports, like the Import button.
        linkField.typeText("\n")

        let save = app.buttons["Save recipe"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: timeout))
        // Save turns on once the first photo has loaded.
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        wait(for: [enabled], timeout: timeout)
        // The keyboard goes once the preview shows.
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
    }

    /// Saves what's on screen, status bar included, as an attachment that
    /// stays in the result bundle even though the test passes.
    @MainActor
    private func saveScreenshot(_ name: String) {
        // Let transitions and fades finish.
        Thread.sleep(forTimeInterval: 1.5)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
