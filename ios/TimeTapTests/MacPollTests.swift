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

    func testSyncFromCalendarAdoptsRemoteSwitch() async {
        pinSession()
        seedOpen(key: "Meetings", ref: "abcdefghijklmnop")
        let store = TapStore()
        store.open = OpenBlock(ref: "oldrefoldrefold1", key: "Deep work", startMs: ApplyOps.nowMs)
        await store.syncFromCalendar()
        XCTAssertEqual(store.open?.key, "Meetings")
    }

    func testSyncFromCalendarAdoptsRemoteClose() async {
        pinSession()
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        ApplyOps.plan = FakeCalendar()
        let store = TapStore()
        store.open = OpenBlock(ref: "oldrefoldrefold1", key: "Deep work", startMs: ApplyOps.nowMs)
        await store.syncFromCalendar()
        XCTAssertNil(store.open)
    }

    func testSyncFromCalendarSkipsAdoptWhilePending() async {
        pinSession()
        seedOpen(key: "Meetings", ref: "abcdefghijklmnop")
        let store = TapStore()
        store.open = OpenBlock(ref: "oldrefoldrefold1", key: "Deep work", startMs: ApplyOps.nowMs)
        store.pendingKey = "Admin"
        await store.syncFromCalendar()
        XCTAssertEqual(store.open?.key, "Deep work")
        XCTAssertEqual(store.pendingKey, "Admin")
    }

    func testSyncFromCalendarAdoptsSit() async {
        pinSession()
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        ApplyOps.plan = FakeCalendar()
        let now = ApplyOps.nowMs
        let ev = ApplyOps.sitting!.createEvent(
            calendarId: "s1", title: TT.sitTitle, startMs: now - 60_000, endMs: now
        )
        ev.description = Grammar.writeDesc("", ref: "sitrefsitrefsit1", isOpen: true)
        let store = TapStore()
        XCTAssertNil(store.sit)
        await store.syncFromCalendar()
        XCTAssertNotNil(store.sit)
    }

    func testSyncFromCalendarNoOpsWhenNotConfigured() async {
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        ApplyOps.plan = FakeCalendar()
        seedOpen(key: "Deep work", ref: "abcdefghijklmnop")
        CalendarAPI.getStateCalls = 0
        let store = TapStore()
        await store.syncFromCalendar()
        XCTAssertNil(store.open)
        XCTAssertEqual(CalendarAPI.getStateCalls, 0)
    }

    func testRootViewKeepsMacPollAfterDisappear() throws {
        let text = try iosSource("TimeTap/Views/RootView.swift")
        let disappear = slice(text, from: ".onDisappear", to: ".onChange(of: scenePhase)")
        XCTAssertTrue(disappear.contains("#if os(iOS)"), "Mac must keep the Calendar poll after the window closes")
        XCTAssertTrue(disappear.contains("stopCalendarPoll"), "iPhone still stops the poll on disappear")
        XCTAssertTrue(text.contains("startCalendarPoll"), "appear must start the poll")
        XCTAssertTrue(text.contains("syncFromCalendar"), "scenePhase active must sync")
    }

    private func seedOpen(key: String, ref: String) {
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        ApplyOps.plan = FakeCalendar()
        let now = ApplyOps.nowMs
        let ev = ApplyOps.actual!.createEvent(
            calendarId: "a1",
            title: Grammar.buildTitle(key, "", nil),
            startMs: now - 60_000,
            endMs: now
        )
        ev.description = Grammar.writeDesc("", ref: ref, isOpen: true)
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

    func testCaptureViewUsesMacToolbarNotTitleBar() throws {
        let text = try iosSource("TimeTap/Views/CaptureView.swift")
        XCTAssertTrue(text.contains("#if os(macOS)"), "Mac chrome is behind os(macOS)")
        XCTAssertTrue(text.contains("macToolbar"), "Mac capture must use a toolbar")
        XCTAssertTrue(text.contains(".toolbar { macToolbar }"), "Mac must attach macToolbar")
        let toolbar = slice(text, from: ".navigationTitle", to: "#if os(iOS)")
        XCTAssertTrue(toolbar.contains(".toolbar { macToolbar }"), "macToolbar is in the macOS toolbar block")
        let mac = slice(text, from: "#if os(macOS)", to: "#else")
        XCTAssertFalse(mac.contains("titleBar"), "Mac must not render the iPhone title bar")
        let phone = slice(text, from: "#else", to: "#endif")
        XCTAssertTrue(phone.contains("titleBar"), "titleBar is in the #else")
        XCTAssertTrue(text.contains("private var titleBar"), "iPhone title bar must stay in the file")
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
