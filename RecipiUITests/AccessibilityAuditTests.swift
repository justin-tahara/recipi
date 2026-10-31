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
    /// Known findings (see `knownFindings`) seen so far, logged but not
    /// failing the test.
    private var knownIssues: [String] = []
    /// The checks to run. The largest-text run leaves out `.dynamicType`.
    private var auditTypes: XCUIAccessibilityAuditType = .all

    @MainActor
    func testMainScreensPassAccessibilityAudit() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        try walkMainScreens(app)

        logKnownIssues()
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
        // The Dynamic Type check makes the text larger and looks for what
        // didn't grow. At the largest size nothing can grow any further, so
        // it flags ordinary text; the run at the default size covers it.
        auditTypes = XCUIAccessibilityAuditType.all.subtracting(.dynamicType)

        try walkMainScreens(app)

        logKnownIssues()
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
        if !app.descendants(matching: .any)["Progress"].firstMatch.exists {
            issues.append("Cooking mode: the progress bar isn't reachable with VoiceOver")
        }
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
        linkField.typeText(fixtureURL)
        // On a slow runner keystrokes can go missing at the largest text
        // size, and a broken link imports nothing. Type it again if so.
        if linkField.value as? String != fixtureURL {
            let clear = app.buttons["Clear link"].firstMatch
            if clear.exists { clear.tap() }
            linkField.tap()
            linkField.typeText(fixtureURL)
        }
        XCTAssertEqual(linkField.value as? String, fixtureURL)
        // Return imports, like the Import button, which large text can push
        // under the keyboard.
        linkField.typeText("\n")

        let save = app.buttons["Save recipe"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: timeout), "No preview after the import. " + importState(app, linkField: linkField))
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        wait(for: [enabled], timeout: timeout)
        save.tap()
    }

    /// What the import sheet shows, for a failure message.
    @MainActor
    private func importState(_ app: XCUIApplication, linkField: XCUIElement) -> String {
        let link = linkField.exists ? (linkField.value as? String ?? "none") : "gone"
        let texts = app.staticTexts.allElementsBoundByIndex.prefix(8).map(\.label)
        return "Link field: \(link). Import recipe button: \(app.buttons["Import recipe"].exists). Text on screen: \(texts)"
    }

    // MARK: - Auditing

    /// Audits what's on screen and notes each issue that isn't a known
    /// false positive (see `isKnownFalsePositive`).
    @MainActor
    private func audit(_ app: XCUIApplication, screen: String) throws {
        // Let fades and sheet dismissals finish first: the contrast check
        // samples the screen's pixels, so text caught mid-fade reads as
        // too faint (seen on "No recipes yet" and the filter row at AX5).
        Thread.sleep(forTimeInterval: 1.5)
        do {
            try performAudit(app, screen: screen)
        } catch let error as NSError where Self.isAuditTimeout(error) {
            // A cold CI simulator can run past the audit's time limit. A
            // timeout reports no issues, so one more try hides nothing.
            try performAudit(app, screen: screen)
        }
    }

    @MainActor
    private func performAudit(_ app: XCUIApplication, screen: String) throws {
        try app.performAccessibilityAudit(for: auditTypes) { issue in
            if self.isKnownFinding(issue, on: screen) {
                self.knownIssues.append("\(screen): \(Self.describe(issue))")
            } else if !self.isKnownFalsePositive(issue, on: screen, in: app) {
                self.issues.append("\(screen): \(Self.describe(issue))")
            }
            // Handled here: reported together at the end of the test.
            return true
        }
    }

    /// "Audit failed to complete in time".
    private static func isAuditTimeout(_ error: NSError) -> Bool {
        error.domain == "com.apple.xcode.xctest.accessibilityAudit" && error.code == -56
    }

    /// Findings the audit reports without saying which element they're on,
    /// so they can't be checked or fixed from here. They're listed as known
    /// findings on the accessibility issue (#21) for a check on a device.
    /// Anything the audit can place on an element still fails the test.
    ///
    /// - Settings: the language picker's chosen value, drawn by the system
    ///   picker row in its own gray (contrast, Dynamic Type).
    /// - Groceries: text inside the grocery rows, which are single buttons
    ///   (Dynamic Type, clipping).
    private static let knownFindings: [(screen: String, type: XCUIAccessibilityAuditType)] = [
        ("Settings", .contrast),
        ("Settings", .dynamicType),
        ("Groceries", .dynamicType),
        ("Groceries", .textClipped),
    ]

    @MainActor
    private func isKnownFinding(_ issue: XCUIAccessibilityAuditIssue, on screen: String) -> Bool {
        issue.element == nil && Self.knownFindings.contains { $0.screen == screen && issue.auditType.contains($0.type) }
    }

    @MainActor
    private func logKnownIssues() {
        guard !knownIssues.isEmpty else { return }
        print("Accessibility audit known findings (\(knownIssues.count)), not failing the test:\n" + knownIssues.joined(separator: "\n"))
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
            // Groceries' "Add an item" field, empty, at the default size:
            // the audit guesses its placeholder may clip at larger sizes.
            // The run at the largest size checks the real layout of that
            // field for clipping, so the guess is left to it.
            if screen == "Groceries", element.elementType == .textField,
               issue.auditType.contains(.textClipped), auditTypes.contains(.dynamicType) {
                return true
            }
            // Settings' Units row is a menu-style Picker, a system control:
            // recipi gives it a label and UIKit lays out the row and the
            // chosen value. The audit reports that row's text as only partly
            // scaling, which recipi can't change short of replacing the
            // control. The menu it opens scales.
            if screen == "Settings" {
                let units = app.staticTexts["Units"].firstMatch
                if units.exists, frame.minY < units.frame.maxY, frame.maxY > units.frame.minY {
                    return true
                }
            }
        }

        guard issue.auditType.contains(.contrast) else { return false }

        // Text the screen edge or the tab bar cuts off is sampled against the
        // edge or the bar's blur, not the page it's on. It's checked when it
        // scrolls into view, as in the walk's other screens.
        let window = app.windows.firstMatch.frame
        if !window.contains(frame) || app.tabBars.allElementsBoundByIndex.contains(where: { $0.frame.intersects(frame) }) {
            return true
        }

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
