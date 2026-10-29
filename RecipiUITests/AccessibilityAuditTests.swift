import XCTest

/// Runs Xcode's accessibility audit (the checks Accessibility Inspector
/// makes: contrast, touch targets, labels, Dynamic Type, clipped text) on the
/// screens the smoke test walks through. Like `SmokeTests`, the app runs
/// with `-ui-testing`: an empty in-memory library and the import served from
/// a fixture page.
///
/// Every issue on every screen is collected and reported together, so one
/// run shows everything to fix.
final class AccessibilityAuditTests: XCTestCase {
    /// Matches `FixturePages.lemonSpaghettiURL` in the app target.
    private let fixtureURL = "https://fixtures.recipi.test/lemon-spaghetti"
    private let timeout: TimeInterval = 10

    /// Issues found so far, one line each.
    private var issues: [String] = []

    @MainActor
    func testMainScreensPassAccessibilityAudit() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        try walkMainScreens(app)

        XCTAssertTrue(issues.isEmpty, "Accessibility audit found \(issues.count) issue(s):\n" + issues.joined(separator: "\n"))
    }

    /// The same walk at the largest accessibility text size, where layouts
    /// switch to stacked and text must wrap rather than clip.
    @MainActor
    func testMainScreensPassAccessibilityAuditAtLargestTextSize() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        try walkMainScreens(app)

        XCTAssertTrue(issues.isEmpty, "Accessibility audit at AX5 found \(issues.count) issue(s):\n" + issues.joined(separator: "\n"))
    }

    // MARK: - The walk

    /// Library (empty, then with a recipe), Settings, the recipe, cooking
    /// mode and the grocery list, auditing each.
    @MainActor
    private func walkMainScreens(_ app: XCUIApplication) throws {
        let importButton = app.buttons["Import from link"].firstMatch
        XCTAssertTrue(importButton.waitForExistence(timeout: timeout))
        try audit(app, screen: "Empty library")

        importFixture(app, from: importButton)
        let row = element("library.recipe", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        try audit(app, screen: "Library")

        app.buttons["Settings"].firstMatch.tap()
        let settings = app.navigationBars["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: timeout))
        try audit(app, screen: "Settings")
        settings.buttons["Done"].tap()
        XCTAssertTrue(settings.waitForNonExistence(timeout: timeout))

        row.tap()
        let servings = element("recipe.servings", in: app)
        XCTAssertTrue(servings.waitForExistence(timeout: timeout))
        try audit(app, screen: "Recipe")

        app.buttons["Start cooking"].firstMatch.tap()
        let next = app.buttons["cooking.next"]
        XCTAssertTrue(next.waitForExistence(timeout: timeout))
        try audit(app, screen: "Cooking mode")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(next.waitForNonExistence(timeout: timeout))

        app.navigationBars.buttons["More"].firstMatch.tap()
        let addToList = app.buttons["Add to grocery list"].firstMatch
        XCTAssertTrue(addToList.waitForExistence(timeout: timeout))
        addToList.tap()
        app.tabBars.buttons["Groceries"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "grocery.item").firstMatch.waitForExistence(timeout: timeout))
        try audit(app, screen: "Groceries")
    }

    @MainActor
    private func importFixture(_ app: XCUIApplication, from importButton: XCUIElement) {
        importButton.tap()
        let linkField = app.textFields.firstMatch
        XCTAssertTrue(linkField.waitForExistence(timeout: timeout))
        linkField.tap()
        // Return imports, like the Import button, which large text can push
        // under the keyboard.
        linkField.typeText(fixtureURL + "\n")

        let save = app.buttons["Save recipe"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: timeout))
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        wait(for: [enabled], timeout: timeout)
        save.tap()
    }

    // MARK: - Auditing

    /// Audits what's on screen and notes each issue that isn't a known
    /// false positive (see `isKnownFalsePositive`).
    @MainActor
    private func audit(_ app: XCUIApplication, screen: String) throws {
        try app.performAccessibilityAudit(for: .all) { issue in
            if !self.isKnownFalsePositive(issue, on: screen, in: app) {
                self.issues.append("\(screen): \(Self.describe(issue))")
            }
            // Handled here: reported together at the end of the test.
            return true
        }
    }

    /// Issues the audit reports that aren't problems a person would meet.
    /// Each case is kept as narrow as it can be; anything else fails.
    @MainActor
    private func isKnownFalsePositive(_ issue: XCUIAccessibilityAuditIssue, on screen: String, in app: XCUIApplication) -> Bool {
        guard let element = issue.element else { return false }
        let frame = element.frame

        // Navigation bars, tab bars and the search field are UIKit's. Their
        // text grows only so far, by design: at the accessibility sizes
        // UIKit shows a long-pressed item in the Large Content Viewer
        // instead, which the audit doesn't count.
        if issue.auditType.contains(.dynamicType) || issue.auditType.contains(.textClipped) {
            if element.elementType == .searchField {
                return true
            }
            let bars = app.navigationBars.allElementsBoundByIndex + app.tabBars.allElementsBoundByIndex
            if bars.contains(where: { $0.frame.contains(frame) }) {
                return true
            }
        }

        guard issue.auditType.contains(.contrast) else { return false }

        // WCAG's contrast rule exempts controls that are turned off, which
        // are meant to look faint (cooking mode's Back on the first step,
        // the iCloud switch in a build with no container).
        if !element.isEnabled {
            return true
        }

        // On a recipe, the page scrolls under the Start cooking bar, whose
        // background fades the page out above the button. Text caught in
        // the fade is checked against the faded page; it is readable once
        // scrolled up. The button's own text is still checked.
        if screen == "Recipe" {
            let startCooking = app.buttons["Start cooking"].firstMatch
            if startCooking.exists, element.label != "Start cooking" {
                // The bar's top padding, Theme.Spacing.lg.
                let fadeTop = startCooking.frame.minY - 24
                if frame.maxY > fadeTop {
                    return true
                }
            }
        }

        return false
    }

    @MainActor
    private static func describe(_ issue: XCUIAccessibilityAuditIssue) -> String {
        var line = "[\(name(of: issue.auditType))] \(issue.compactDescription)"
        if let element = issue.element {
            line += " | element: type \(element.elementType.rawValue), label \"\(element.label)\", identifier \"\(element.identifier)\", frame \(element.frame)"
        }
        line += " | \(issue.detailedDescription)"
        return line
    }

    private static func name(of type: XCUIAccessibilityAuditType) -> String {
        let names: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contrast"),
            (.elementDetection, "elementDetection"),
            (.hitRegion, "hitRegion"),
            (.sufficientElementDescription, "sufficientElementDescription"),
            (.dynamicType, "dynamicType"),
            (.textClipped, "textClipped"),
            (.trait, "trait"),
        ]
        return names.first { type.contains($0.0) }?.1 ?? "\(type.rawValue)"
    }

    /// Finds an element by identifier whatever its accessibility type.
    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
