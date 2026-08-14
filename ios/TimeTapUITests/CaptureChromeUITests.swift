import XCTest

final class CaptureChromeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-tt-ui-smoke"]
        app.launch()
    }

    func testNoteFieldOpensFromRailAndIsWide() {
        let elapsed = app.buttons["elapsed"]
        XCTAssertTrue(elapsed.waitForExistence(timeout: 8), "elapsed is missing")
        XCTAssertFalse(app.buttons["addNote"].exists, "ADD NOTE chip must be gone")
        let open = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "open")
        ).firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 4), "open rail block is missing")
        open.tap()
        let field = app.textFields["noteField"]
        XCTAssertTrue(field.waitForExistence(timeout: 4), "note field must open")
        XCTAssertGreaterThanOrEqual(
            field.frame.width,
            app.frame.width * 0.8,
            "note field must span full NOW width"
        )
    }

    func testSitChipNamesNotSitting() {
        let chip = app.buttons["sitChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 8), "sit chip is missing")
        let value = (chip.value as? String) ?? chip.label
        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("NOT SITTING")
                || value.localizedCaseInsensitiveContains("Not sitting"),
            "sit chip must name NOT SITTING, got \(value)"
        )
        XCTAssertFalse(value.localizedCaseInsensitiveContains("STANDING"))
    }
}
