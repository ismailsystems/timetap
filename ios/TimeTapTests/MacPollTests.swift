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

    func testTapStorePollCallsSyncFromCalendar() throws {
        let text = try iosSource("TimeTap/Services/TapStore.swift")
        XCTAssertTrue(text.contains("MacSync.pollNs"), "calendar poll must use MacSync.pollNs")
        XCTAssertTrue(text.contains("syncFromCalendar"), "calendar poll must call syncFromCalendar")
        let poll = slice(text, from: "func startCalendarPoll()", to: "func stopCalendarPoll()")
        XCTAssertTrue(poll.contains("syncFromCalendar"), "startCalendarPoll must call syncFromCalendar")
        XCTAssertFalse(
            poll.contains("refreshOnReturnNow"),
            "poll must not use the 10-minute return gate"
        )
    }

    func testSyncFromCalendarLoadsWhileReturnGateWouldSkip() async {
        pinSession()
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        ApplyOps.plan = FakeCalendar()
        let now = ApplyOps.nowMs
        let ev = ApplyOps.actual!.createEvent(
            calendarId: "a1",
            title: Grammar.buildTitle("Meetings", "", nil),
            startMs: now - 60_000,
            endMs: now
        )
        ev.description = Grammar.writeDesc("", ref: "abcdefghijklmnop", isOpen: true)
        let store = TapStore()
        XCTAssertNil(store.open)
        await store.syncFromCalendar()
        XCTAssertEqual(store.open?.key, "Meetings")
    }

    func testSyncFromCalendarAdoptsLiveDistract() async {
        pinSession()
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        ApplyOps.plan = FakeCalendar()
        let now = ApplyOps.nowMs
        let ev = ApplyOps.actual!.createEvent(
            calendarId: "a1",
            title: Grammar.buildTitle("Deep work", "", nil),
            startMs: now - 60_000,
            endMs: now
        )
        ev.description = Grammar.stampLiveDistract(
            Grammar.writeDesc("", ref: "abcdefghijklmnop", isOpen: true),
            accruedMs: 2_000,
            startMs: now - 1_000
        )
        let store = TapStore()
        await store.syncFromCalendar()
        XCTAssertEqual(store.open?.key, "Deep work")
        XCTAssertTrue(store.distracted)
        XCTAssertEqual(store.currentDistractedMs(), 3_000, accuracy: 250)
    }

    private func pinSession() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }

    private func slice(_ text: String, from: String, to: String) -> String {
        let start = text.range(of: from)!.lowerBound
        let end = text.range(of: to, range: start..<text.endIndex)?.lowerBound ?? text.endIndex
        return String(text[start..<end])
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
