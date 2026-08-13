import XCTest

final class CaptureChromeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-tt-ui-smoke"]
        app.launch()
    }

    func testAddNoteSitsRightOfElapsedThenNoteFieldIsWide() {
        let elapsed = app.buttons["elapsed"]
        let add = app.buttons["addNote"]
        XCTAssertTrue(elapsed.waitForExistence(timeout: 8), "elapsed is missing")
        XCTAssertTrue(add.waitForExistence(timeout: 8), "ADD NOTE is missing")
        XCTAssertGreaterThan(add.frame.minX, elapsed.frame.maxX - 1, "ADD NOTE must sit to the right of elapsed")
        let overlapY = min(add.frame.maxY, elapsed.frame.maxY) - max(add.frame.minY, elapsed.frame.minY)
        XCTAssertGreaterThan(overlapY, 0, "ADD NOTE and elapsed must share a row")
        add.tap()
        let field = app.textFields["noteField"]
        XCTAssertTrue(field.waitForExistence(timeout: 4), "note field must open")
        XCTAssertGreaterThanOrEqual(
            field.frame.width,
            app.frame.width * 0.8,
            "note field must span full width under STOP"
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
