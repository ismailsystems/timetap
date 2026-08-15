import XCTest
@testable import TimeTapMac

final class MacChromeTests: XCTestCase {
    func testTimeTapMacAppWiresChromeAndOmitsWatchAndLiveActivity() throws {
        let text = try iosSource("TimeTapMac/TimeTapMacApp.swift")
        XCTAssertTrue(text.contains("StatusItemController.start"), "Mac app must start the status item")
        XCTAssertTrue(text.contains("MacCommandHub.store"), "Mac app must pin the command hub store")
        XCTAssertTrue(text.contains("MacCommands"), "Mac app must install MacCommands")
        XCTAssertFalse(text.contains("WatchBridge"), "Mac app must not activate WatchBridge")
        XCTAssertFalse(text.contains("LiveActivityDarwin"), "Mac app must not activate LiveActivityDarwin")
    }

    func testCaptureViewHasMacChromeAndKeepsPlanActualRails() throws {
        let text = try iosSource("TimeTap/Views/CaptureView.swift")
        XCTAssertTrue(text.contains("#if os(macOS)"), "capture must gate Mac chrome")
        XCTAssertTrue(text.contains("macChrome"), "capture must host macChrome")
        XCTAssertTrue(text.contains("toggleDistract"), "Mac chrome must toggle distract")
        XCTAssertTrue(text.contains("keyboardShortcut(\"d\")"), "Distracted stays on d")
        XCTAssertTrue(text.contains("keyboardShortcut(\".\")"), "Stop stays on period")
        XCTAssertTrue(text.contains("source: .plan"), "left rail is PLAN")
        XCTAssertTrue(text.contains("source: .actual"), "right rail is ACTUAL")
        XCTAssertFalse(text.contains("categoryList"), "category column is gone")
    }

    func testProjectYmlMacTargetExcludesWatchAndLiveActivity() throws {
        let yml = try iosSource("project.yml")
        XCTAssertTrue(yml.contains("TimeTapMac"), "project.yml must name TimeTapMac")
        XCTAssertTrue(yml.contains("app.timetap.mac"), "Mac bundle id must stay app.timetap.mac")
        let start = try XCTUnwrap(yml.range(of: "  TimeTapMac:"), "TimeTapMac target is gone")
        let rest = yml[start.lowerBound...]
        let stop = try XCTUnwrap(rest.range(of: "  TimeTapMacTests:"), "TimeTapMacTests target is gone")
        let mac = String(yml[start.lowerBound..<stop.lowerBound])
        XCTAssertTrue(mac.contains("app.timetap.mac"), "Mac target bundle id is app.timetap.mac")
        XCTAssertTrue(mac.contains("excludes:"), "Mac target must exclude iOS-only sources")
        XCTAssertTrue(mac.contains("Watch/WatchBridge.swift"), "Mac target must exclude WatchBridge")
        XCTAssertTrue(mac.contains("LiveActivity"), "Mac target must exclude LiveActivity")
    }

    func testMacCommandsHasDistractStopSitShortcuts() throws {
        let text = try iosSource("TimeTapMac/MacCommands.swift")
        XCTAssertTrue(text.contains("keyboardShortcut(\"d\")"), "Distracted stays on d")
        XCTAssertTrue(text.contains("keyboardShortcut(\".\")"), "Stop stays on period")
        XCTAssertTrue(text.contains("keyboardShortcut(\"s\")"), "Sit stays on s")
    }

    func testStatusItemControllerProposesAndTogglesDistract() throws {
        let text = try iosSource("TimeTapMac/StatusItemController.swift")
        XCTAssertTrue(text.contains("propose"), "status item must propose a category")
        XCTAssertTrue(text.contains("toggleDistract"), "status item must toggle distract")
    }

    func testGoogleAuthPresentsFromAppKitKeyWindow() throws {
        let text = try iosSource("TimeTap/Services/GoogleAuth.swift")
        XCTAssertTrue(text.contains("NSApp.keyWindow"), "Mac sign-in presents from the key window")
        XCTAssertTrue(text.contains("canImport(AppKit)"), "GoogleAuth must compile AppKit on Mac")
    }

    func testRootViewStartsCalendarPollAndSkipsUISmoke() throws {
        let text = try iosSource("TimeTap/Views/RootView.swift")
        XCTAssertTrue(text.contains("startCalendarPoll"), "root must start the calendar poll")
        XCTAssertTrue(text.contains("TimeTapRuntime.isUISmoke"), "root must skip poll work in UI smoke")
    }

    private func iosSource(_ relative: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(relative),
            encoding: .utf8
        )
    }
}
