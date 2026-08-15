import XCTest
@testable import TimeTap

@MainActor
final class MacPollTests: TimeTapTestCase {
    func testPollNsActiveAndIdle() {
        XCTAssertEqual(MacSync.pollNs(active: true), 15_000_000_000)
        XCTAssertEqual(MacSync.pollNs(active: false), 60_000_000_000)
    }

    func testStartCalendarPollIsIdempotent() {
        let store = TapStore()
        store.startCalendarPoll()
        store.startCalendarPoll()
        store.stopCalendarPoll()
    }

    func testTapStoreContainsPollNsAndRefreshOnReturnNow() throws {
        let text = try iosSource("TimeTap/Services/TapStore.swift")
        XCTAssertTrue(text.contains("MacSync.pollNs"), "calendar poll must use MacSync.pollNs")
        XCTAssertTrue(text.contains("refreshOnReturnNow"), "calendar poll must call refreshOnReturnNow")
    }

    func testTimeTapMacAppContainsNoWatchBridge() throws {
        let text = try iosSource("TimeTapMac/TimeTapMacApp.swift")
        XCTAssertFalse(text.contains("WatchBridge"), "Mac app must not activate WatchBridge")
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
