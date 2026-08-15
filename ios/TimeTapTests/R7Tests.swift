import XCTest
@testable import TimeTap

@MainActor
final class R7Tests: TimeTapTestCase {
    let t: Double = 1_700_000_000_000
    let dw = "abcdefghijklmnop"
    let mtg = "mtgmtgmtgmtgmtg1"
    let chicago = TimeZone(identifier: "America/Chicago")!

    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
        ApplyOps.nowMs = t + 1_200_000
        ApplyOps.timeZone = TimeZone(secondsFromGMT: 0)!
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }

    override func tearDown() {
        ApplyOps.resetForTests()
        CalendarAPI.resetTestHTTP()
        Grammar.extraColors = [:]
        super.tearDown()
    }

    // MARK: - P3-R7-1

    func testBootListsAndAdoptsClosedDWAndOpenMTG() async {
        seedListedClosedDWOpenMTG()
        let store = TapStore()
        await store.bootNow()
        XCTAssertEqual(store.open?.key, "Meetings")
        XCTAssertTrue(store.today.contains { $0.key == "Deep work" })
        XCTAssertNil(store.banner)
    }

    func testBootWithNoListSeamShowsReadError() async {
        ApplyOps.actual = nil
        ApplyOps.sitting = nil
        let store = TapStore()
        await store.bootNow()
        XCTAssertEqual(store.banner, "calendars missing")
        XCTAssertNil(store.open)
        XCTAssertTrue(store.today.isEmpty)
    }

    func testSignInWithSavedIdsLoadsState() async {
        seedListedClosedDWOpenMTG()
        let store = TapStore()
        store.showSignIn = true
        await store.didSignIn()
        XCTAssertFalse(store.showSignIn)
        XCTAssertEqual(store.open?.key, "Meetings")
        XCTAssertTrue(store.today.contains { $0.key == "Deep work" })
        XCTAssertNil(store.banner)
    }

    func testPickerConfirmLoadsState() async {
        seedListedClosedDWOpenMTG()
        let store = TapStore()
        store.showPicker = true
        await store.didConfirmCalendars()
        XCTAssertFalse(store.showPicker)
        XCTAssertEqual(store.open?.key, "Meetings")
        XCTAssertTrue(store.today.contains { $0.key == "Deep work" })
        XCTAssertNil(store.banner)
    }

    func testListThrowKeepsPersistedOpen() async {
        let store = TapStore()
        store.open = OpenBlock(ref: dw, key: "Deep work", startMs: t)
        store.today = [TodayBlock(key: "Meetings", startMs: t, endMs: t + 600_000)]
        CalendarAPI.testStateError = "boom"
        await store.bootNow()
        XCTAssertEqual(store.open?.key, "Deep work")
        XCTAssertEqual(store.open?.ref, dw)
        XCTAssertEqual(store.today.map(\.key), ["Meetings"])
        XCTAssertEqual(store.banner, "boom")
    }

    func testOvernightGetStatePushesGuessAndUnlogged() async throws {
        let listed = seedOvernightOpenDW()
        _ = try await CalendarAPI.refreshState()
        XCTAssertTrue(CalendarAPI.didPushState)
        let dwEv = listed.events.first { $0.title.hasPrefix("Deep work") }!
        XCTAssertTrue(dwEv.title.hasSuffix("?"))
        XCTAssertFalse(dwEv.description.contains("#open"))
        XCTAssertEqual(dwEv.endMs, ApplyOps.addLocalDays(local(2026, 1, 15, 22), 1))
        let un = listed.events.first { $0.title == "UNLOGGED -" }!
        XCTAssertEqual(un.startMs, dwEv.endMs)
        XCTAssertEqual(un.endMs, local(2026, 1, 16, 7))
    }

    func testSkipStatePushLeavesUnmarkedOpenDW() async throws {
        let listed = seedOvernightOpenDW()
        CalendarAPI.skipStatePush = true
        _ = try await CalendarAPI.refreshState()
        XCTAssertFalse(CalendarAPI.didPushState)
        let dwEv = listed.events.first { $0.title.hasPrefix("Deep work") }!
        XCTAssertTrue(dwEv.description.contains("#open"))
        XCTAssertFalse(dwEv.title.hasSuffix("?"))
        XCTAssertFalse(listed.events.contains { $0.title == "UNLOGGED -" })
    }

    func testOvernightBootShowsClosedGuessBanner() async {
        seedOvernightOpenDW()
        let store = TapStore()
        await store.bootNow()
        XCTAssertNil(store.open)
        XCTAssertEqual(
            store.banner,
            "an overnight block was closed with a guess. Check the calendar."
        )
        XCTAssertFalse(store.unreadableOpen)
    }

    // MARK: - P3-R7-2

    func testCancelDoesNotPinTheTestSeam() {
        GoogleAuth.testHasSession = nil
        GoogleAuth.testAccessToken = "leftover"
        GoogleAuth.applyCancelledSignIn()
        XCTAssertNil(GoogleAuth.testHasSession, "production cancel must not pin testHasSession")
        XCTAssertNil(GoogleAuth.testAccessToken)
        XCTAssertFalse(GoogleAuth.hasSession)
        XCTAssertTrue(GoogleAuth.lastSignInCancelled)
    }

    func testSignOutDoesNotPinTheTestSeam() {
        GoogleAuth.testHasSession = nil
        GoogleAuth.signOut()
        XCTAssertNil(GoogleAuth.testHasSession, "sign-out must not pin testHasSession either")
        XCTAssertFalse(GoogleAuth.hasSession)
    }

    func testAfterCancelALaterTestSessionIsVisible() {
        GoogleAuth.testHasSession = nil
        GoogleAuth.applyCancelledSignIn()
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        let store = TapStore()
        store.showSignIn = false
        store.tapCategory("Deep work")
        XCTAssertFalse(store.showSignIn)
        XCTAssertTrue(store.queue.contains { $0.type == "openActual" && $0.key == "Deep work" })
    }

    func testFollowSDKSessionClearsAPinnedFalseSeam() {
        GoogleAuth.testHasSession = false
        GoogleAuth.testAccessToken = "x"
        GoogleAuth.followSDKSession()
        XCTAssertNil(GoogleAuth.testHasSession)
        XCTAssertNil(GoogleAuth.testAccessToken)
    }

    // MARK: - P3-R7-3

    func testDeepReadingOpenActualKeepsNextColor() throws {
        let store = TapStore()
        store.addCategory(label: "Deep reading")
        XCTAssertEqual(Grammar.colorId(for: "Deep reading"), "1")
        let actual = FakeCalendar()
        ApplyOps.actual = actual
        ApplyOps.sitting = FakeCalendar()
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "Deep reading", startMs: t)
        ])
        XCTAssertEqual(actual.events[0].colorId, "1")
        let ev = try CalendarAPI.openActual(key: "Deep reading", at: t, ref: dw)
        XCTAssertEqual(ev.colorId, "1")
    }

    // MARK: - Seams

    @discardableResult
    private func seedListedClosedDWOpenMTG() -> FakeCalendar {
        let listed = FakeCalendar()
        let sit = FakeCalendar()
        ApplyOps.actual = listed
        ApplyOps.sitting = sit
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "Deep work", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "Deep work", mark: "=", endMs: t + 600_000),
            Op(id: "o2", type: "openActual", ref: mtg, key: "Meetings", startMs: t + 600_000),
        ])
        CalendarAPI.testListedActual = listed
        CalendarAPI.testListedSitting = sit
        ApplyOps.actual = nil
        ApplyOps.sitting = nil
        return listed
    }

    @discardableResult
    private func seedOvernightOpenDW() -> FakeCalendar {
        let start = local(2026, 1, 15, 22)
        ApplyOps.timeZone = chicago
        ApplyOps.nowMs = start
        let listed = FakeCalendar()
        ApplyOps.actual = listed
        ApplyOps.sitting = FakeCalendar()
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "Deep work", startMs: start)])
        CalendarAPI.testListedActual = listed
        CalendarAPI.testListedSitting = FakeCalendar()
        ApplyOps.actual = nil
        ApplyOps.sitting = nil
        ApplyOps.nowMs = local(2026, 1, 16, 7)
        return listed
    }

    private func local(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Double {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = chicago
        return cal.date(from: c)!.timeIntervalSince1970 * 1000
    }
}
