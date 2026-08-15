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

    private func pinSession() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }
}
