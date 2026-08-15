import XCTest
@testable import TimeTap

@MainActor
final class DistractedTests: TimeTapTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
        GoogleAuth.resetForTests()
        for key in ["tt.queue.v1", "tt.state.v1", "tt.dead.v1", "tt.blocks.v1"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func testToggleDistractDoesNotChangeOpenKey() {
        pinSession()
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("Deep work")
        XCTAssertEqual(store.open?.key, "Deep work")
        store.toggleDistract()
        XCTAssertTrue(store.distracted)
        XCTAssertEqual(store.open?.key, "Deep work")
        now += 1_000
        store.toggleDistract()
        XCTAssertFalse(store.distracted)
        XCTAssertEqual(store.open?.key, "Deep work")
    }

    func testToggleDistractIsNoOpWhenNothingIsRunning() {
        pinSession()
        let store = TapStore()
        XCTAssertNil(store.open)
        XCTAssertFalse(store.distracted)
        store.toggleDistract()
        XCTAssertNil(store.open)
        XCTAssertFalse(store.distracted)
        XCTAssertTrue(store.queue.isEmpty)
    }

    func testCloseActualKeepsTwoMinutesOfDistractThenClears() {
        pinSession()
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("Deep work")
        store.toggleDistract()
        XCTAssertTrue(store.distracted)
        now += 120_000
        store.toggleDistract()
        XCTAssertFalse(store.distracted)
        XCTAssertEqual(store.open?.key, "Deep work")
        now += 300
        store.tapCategory("Meetings")
        let close = store.queue.first { $0.type == "closeActual" && $0.key == "Deep work" }
        XCTAssertEqual(close?.distractedMs, 120_000)
        XCTAssertEqual(store.open?.key, "Meetings")
        XCTAssertFalse(store.distracted)
    }

    func testStampReadAndWriteDescKeepEightyPercentOnTask() {
        let blockMs = 15 * 60_000.0
        let distractedMs = 3 * 60_000.0
        XCTAssertEqual(Grammar.onTaskPercent(distractedMs: distractedMs, blockMs: blockMs), 80)
        let stamped = Grammar.stampDistract("memo", distractedMs: distractedMs, blockMs: blockMs)
        XCTAssertEqual(Grammar.readDistract(stamped), distractedMs)
        XCTAssertTrue(stamped.contains("#ontask:80"), "15 min block, 3 min distract is 80% on-task")
        let written = Grammar.writeDesc(stamped, ref: "abcdefghijklmnop", isOpen: false)
        XCTAssertEqual(Grammar.readDistract(written), distractedMs)
        XCTAssertTrue(written.contains("#ontask:80"), "writeDesc must keep the on-task tag")
        XCTAssertTrue(written.contains("#distracted:180000"), "writeDesc must keep the distract tag")
        XCTAssertTrue(written.contains("#ref:abcdefghijklmnop"))
        XCTAssertFalse(written.contains("#open"))
    }

    func testLiveDistractStampRoundTripsAndCloseStripsIt() {
        let live = Grammar.stampLiveDistract("memo", accruedMs: 12_000, startMs: 1_700_000_000_000)
        let read = Grammar.readLiveDistract(live)
        XCTAssertEqual(read?.accruedMs, 12_000)
        XCTAssertEqual(read?.startMs, 1_700_000_000_000)
        let closed = Grammar.stampDistract(live, distractedMs: 12_000, blockMs: 60_000)
        XCTAssertNil(Grammar.readLiveDistract(closed))
        XCTAssertEqual(Grammar.readDistract(closed), 12_000)
    }

    func testToggleDistractEnqueuesSetDistract() {
        pinSession()
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("Deep work")
        store.toggleDistract()
        let on = store.queue.last { $0.type == "setDistract" }
        XCTAssertEqual(on?.startMs, now)
        XCTAssertEqual(on?.distractedMs, 0)
        now += 5_000
        store.toggleDistract()
        let off = store.queue.last { $0.type == "setDistract" }
        XCTAssertEqual(off?.startMs, 0)
        XCTAssertEqual(off?.distractedMs, 5_000)
    }

    func testGetStateReadsLiveDistractOntoServerState() throws {
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        ApplyOps.nowMs = 1_700_000_060_000
        let ev = ApplyOps.actual!.createEvent(
            calendarId: "a1",
            title: Grammar.buildTitle("Deep work", "", nil),
            startMs: 1_700_000_000_000,
            endMs: 1_700_000_060_000
        )
        ev.description = Grammar.stampLiveDistract(
            Grammar.writeDesc("", ref: "abcdefghijklmnop", isOpen: true),
            accruedMs: 4_000,
            startMs: 1_700_000_050_000
        )
        let st = try ApplyOps.getState()
        XCTAssertEqual(st.open?.key, "Deep work")
        XCTAssertEqual(st.distracted, true)
        XCTAssertEqual(st.distractedAccruedMs, 4_000)
        XCTAssertEqual(st.distractStartMs, 1_700_000_050_000)
    }

    func testApplySetDistractWritesLiveTag() {
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        let t = ApplyOps.nowMs.rounded()
        ApplyOps.nowMs = t
        let ref = "abcdefghijklmnop"
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: ref, key: "Deep work", startMs: t)
        ])
        _ = ApplyOps.apply([
            Op(
                id: "d1", type: "setDistract", ref: ref,
                startMs: t + 1_000, hintMs: t, distractedMs: 0
            )
        ])
        let ev = ApplyOps.actual!.events[0]
        let live = Grammar.readLiveDistract(ev.description)
        XCTAssertEqual(live?.accruedMs, 0)
        XCTAssertEqual(live?.startMs, t + 1_000)
        XCTAssertTrue(ev.description.contains("#open"))
    }

    func testCloseActualWithZeroDistractStripsLiveTag() {
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        let t = ApplyOps.nowMs.rounded()
        ApplyOps.nowMs = t
        let ref = "abcdefghijklmnop"
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: ref, key: "Deep work", startMs: t)
        ])
        _ = ApplyOps.apply([
            Op(id: "d1", type: "setDistract", ref: ref, startMs: t + 1_000, hintMs: t, distractedMs: 0)
        ])
        _ = ApplyOps.apply([
            Op(id: "c1", type: "closeActual", ref: ref, key: "Deep work", endMs: t + 60_000)
        ])
        let ev = ApplyOps.actual!.events[0]
        XCTAssertNil(Grammar.readLiveDistract(ev.description))
        XCTAssertFalse(ev.description.contains("#open"))
        XCTAssertNil(Grammar.readDistract(ev.description))
    }

    func testCloseActualKeepsAccruedAndStripsLiveTag() {
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        let t = ApplyOps.nowMs.rounded()
        ApplyOps.nowMs = t
        let ref = "abcdefghijklmnop"
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: ref, key: "Deep work", startMs: t)
        ])
        _ = ApplyOps.apply([
            Op(id: "d1", type: "setDistract", ref: ref, startMs: t + 1_000, hintMs: t, distractedMs: 0)
        ])
        _ = ApplyOps.apply([
            Op(
                id: "c1", type: "closeActual", ref: ref, key: "Deep work",
                endMs: t + 60_000, distractedMs: 12_000
            )
        ])
        let ev = ApplyOps.actual!.events[0]
        XCTAssertNil(Grammar.readLiveDistract(ev.description))
        XCTAssertEqual(Grammar.readDistract(ev.description), 12_000)
        XCTAssertFalse(ev.description.contains("#open"))
    }

    func testGetStateOffLiveTagClearsStart() throws {
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        ApplyOps.nowMs = 1_700_000_060_000
        let ev = ApplyOps.actual!.createEvent(
            calendarId: "a1",
            title: Grammar.buildTitle("Deep work", "", nil),
            startMs: 1_700_000_000_000,
            endMs: 1_700_000_060_000
        )
        ev.description = Grammar.stampLiveDistract(
            Grammar.writeDesc("", ref: "abcdefghijklmnop", isOpen: true),
            accruedMs: 4_000,
            startMs: 0
        )
        let st = try ApplyOps.getState()
        XCTAssertEqual(st.distracted, false)
        XCTAssertEqual(st.distractedAccruedMs, 4_000)
        XCTAssertNil(st.distractStartMs)
    }

    private func pinSession() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }
}
