import XCTest
@testable import TimeTap

/// Watch radios through the iPhone. The Mac uses Calendar as the sync bus
/// and never activates WCSession.
final class MacWatchBoundaryTests: TimeTapTestCase {
    func testTimeTapMacSourcesExcludeWatchBridge() throws {
        let yml = try iosSource("project.yml")
        let mac = slice(yml, from: "  TimeTapMac:\n", to: "  TimeTapMacTests:")
        XCTAssertTrue(mac.contains("platform: macOS"), "TimeTapMac must stay a macOS target")
        XCTAssertTrue(
            mac.contains("Watch/WatchBridge.swift"),
            "TimeTapMac sources must name Watch/WatchBridge.swift"
        )
        XCTAssertTrue(
            mac.contains("- Watch/WatchBridge.swift"),
            "TimeTapMac sources must exclude Watch/WatchBridge.swift"
        )
        let ios = slice(yml, from: "  TimeTap:\n", to: "  TimeTapWatch:")
        XCTAssertFalse(
            ios.contains("Watch/WatchBridge.swift"),
            "the iPhone target must keep WatchBridge"
        )
    }

    func testWatchCompanionIsIPhoneNotMac() throws {
        let plist = try iosSource("TimeTapWatch/Info.plist")
        XCTAssertTrue(
            plist.contains("<key>WKCompanionAppBundleIdentifier</key>"),
            "Watch Info.plist must name a companion"
        )
        XCTAssertTrue(
            plist.contains("<string>app.timetap.ios</string>"),
            "Watch companions the iPhone, not the Mac"
        )
        XCTAssertFalse(
            plist.contains("app.timetap.mac"),
            "Watch must not companion the Mac bundle"
        )

        let yml = try iosSource("project.yml")
        let watch = slice(yml, from: "  TimeTapWatch:\n", to: "  TimeTapWatchWidgets:")
        XCTAssertTrue(
            watch.contains("WKCompanionAppBundleIdentifier: app.timetap.ios"),
            "project.yml must keep WKCompanionAppBundleIdentifier: app.timetap.ios"
        )
        XCTAssertFalse(
            watch.contains("app.timetap.mac"),
            "Watch project settings must not companion the Mac"
        )
    }

    func testTimeTapMacAppHasNoWatchConnectivity() throws {
        let text = try iosSource("TimeTapMac/TimeTapMacApp.swift")
        XCTAssertFalse(text.contains("WCSession"), "Mac app must not touch WCSession")
        XCTAssertFalse(text.contains("WatchBridge"), "Mac app must not start WatchBridge")
        XCTAssertFalse(
            text.contains("WatchConnectivity"),
            "Mac app must not import WatchConnectivity"
        )
    }

    func testWatchBridgeAppliesProposeToggleDistractAndEndDay() throws {
        let text = try iosSource("TimeTap/Watch/WatchBridge.swift")
        XCTAssertTrue(text.contains("store.propose"), "WatchBridge must call store.propose")
        XCTAssertTrue(
            text.contains("store.toggleDistract()"),
            "WatchBridge must call store.toggleDistract"
        )
        XCTAssertTrue(text.contains("store.endDay()"), "WatchBridge must call store.endDay")
        let apply = slice(text, from: "private func apply(", to: "nonisolated func session(")
        XCTAssertTrue(apply.contains("store.propose"), "apply must call store.propose")
        XCTAssertTrue(
            apply.contains("store.toggleDistract()"),
            "apply must call store.toggleDistract"
        )
        XCTAssertTrue(apply.contains("store.endDay()"), "apply must call store.endDay")
    }

    func testStatusItemHasSitAndShow() throws {
        let text = try iosSource("TimeTapMac/StatusItemController.swift")
        XCTAssertTrue(text.contains("toggleSit"), "menu bar extra must offer Sit")
        XCTAssertTrue(text.contains("Show TimeTap"), "menu bar extra must offer Show TimeTap")
        XCTAssertFalse(text.contains("WCSession"), "menu bar extra must not touch WCSession")
    }

    func testMacSyncNeverActivatesWCSession() throws {
        let text = try iosSource("TimeTap/Mac/MacSync.swift")
        XCTAssertTrue(
            text.contains("never activates WCSession")
                || text.contains("The Mac never activates WCSession"),
            "MacSync must say the Mac never activates WCSession"
        )
        XCTAssertTrue(
            text.contains("Calendar is the sync bus")
                || text.contains("Calendar"),
            "MacSync must name Calendar as the sync bus"
        )
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

    private func slice(_ text: String, from: String, to: String? = nil) -> String {
        let start = text.range(of: from)!.lowerBound
        let end = to.flatMap {
            text.range(of: $0, range: start..<text.endIndex)?.lowerBound
        } ?? text.endIndex
        return String(text[start..<end])
    }
}
