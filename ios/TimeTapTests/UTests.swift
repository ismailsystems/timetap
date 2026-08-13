import XCTest
@testable import TimeTap

@MainActor
final class UTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
    }

    func testInitDoesNotFlashSignInWhenSeamIsUnpinned() {
        GoogleAuth.testHasSession = nil
        let store = TapStore()
        XCTAssertFalse(store.showSignIn)
        XCTAssertFalse(store.showPicker)
    }

    func testFreshSplitSliderRangeIsNotAPoint() {
        let t: Double = 1_700_000_000_000
        let range = TapStore.splitSliderRange(startMs: t, nowMs: t)
        XCTAssertEqual(range.lowerBound, 1)
        XCTAssertEqual(range.upperBound, 2)
        XCTAssertGreaterThan(range.upperBound, range.lowerBound)
        let hour = TapStore.splitSliderRange(startMs: t, nowMs: t + 3_600_000)
        XCTAssertEqual(hour.upperBound, 59)
    }

    func testCaptureViewHasNoKeyboardDoneBar() throws {
        let ios = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let text = try String(
            contentsOf: ios.appendingPathComponent("TimeTap/Views/CaptureView.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(text.contains("Button(\"Done\")"), "keyboard Done bar is back")
        XCTAssertFalse(text.contains("axis: .vertical"), "note field must stay single-line so the key is Done")
        XCTAssertTrue(text.contains("if store.open != nil"), "note field must hide when nothing is running")
    }
}
