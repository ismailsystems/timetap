import XCTest
@testable import TimeTapMac

@MainActor
final class MacSyncTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
    }

    override func tearDown() {
        Credentials.resetForTests()
        super.tearDown()
    }

    func testPollNsActiveIsFifteenSeconds() {
        XCTAssertEqual(MacSync.pollNs(active: true), 15_000_000_000)
    }

    func testPollNsIdleIsSixtySeconds() {
        XCTAssertEqual(MacSync.pollNs(active: false), 60_000_000_000)
    }

    func testStartAndStopCalendarPollAreIdempotent() {
        pinSession()
        let store = TapStore()
        store.startCalendarPoll()
        store.stopCalendarPoll()
        store.stopCalendarPoll()
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

    private func pinSession() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }
}
