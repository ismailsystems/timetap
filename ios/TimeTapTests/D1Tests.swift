import XCTest
@testable import TimeTap

@MainActor
final class D1Tests: TimeTapTestCase {
    let actual = FakeCalendar()

    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
        ApplyOps.actual = actual
        ApplyOps.sitting = FakeCalendar()
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }

    func testSettingsConfirmActualA2UsedOnNextInsert() async {
        XCTAssertTrue(CalendarAPI.confirm(plan: "p1", actual: "a2", sitting: "s1"))
        XCTAssertEqual(Credentials.actualId, "a2")
        let store = TapStore()
        store.tapCategory("Deep work")
        await store.flushNow()
        XCTAssertEqual(actual.events.count, 1)
        XCTAssertEqual(actual.events[0].calendarId, "a2")
        XCTAssertNotEqual(actual.events[0].calendarId, "a1")
    }

        func testSignOutClearsGoogleKeepsIdsAcrossRelaunch() async {
        let store = TapStore()
        store.signOut()
        XCTAssertFalse(GoogleAuth.hasSession)
        XCTAssertNil(GoogleAuth.accessToken)
        XCTAssertEqual(Credentials.planId, "p1")
        XCTAssertEqual(Credentials.actualId, "a1")
        XCTAssertEqual(Credentials.sittingId, "s1")
        GoogleAuth.testHasSession = false
        let again = TapStore()
        await again.bootNow()
        XCTAssertEqual(Credentials.planId, "p1")
        XCTAssertEqual(Credentials.actualId, "a1")
        XCTAssertEqual(Credentials.sittingId, "s1")
        XCTAssertTrue(again.showSignIn)
        XCTAssertFalse(GoogleAuth.hasSession)
    }

    func testSignedOutTapDoesNotInsertAndShowsSignIn() {
        GoogleAuth.signOut()
        GoogleAuth.testHasSession = false
        GoogleAuth.didAttemptCalendarWrite = false
        let store = TapStore()
        store.tapCategory("Deep work")
        XCTAssertTrue(store.showSignIn)
        XCTAssertTrue(actual.events.isEmpty)
        XCTAssertTrue(store.queue.isEmpty)
        XCTAssertFalse(GoogleAuth.didAttemptCalendarWrite)
    }

    func testConfirmWithSittingClearedDoesNotOverwriteIds() {
        XCTAssertFalse(CalendarAPI.confirm(plan: "p1", actual: "a2", sitting: nil))
        XCTAssertFalse(CalendarAPI.confirm(plan: "p1", actual: "a2", sitting: ""))
        XCTAssertEqual(Credentials.planId, "p1")
        XCTAssertEqual(Credentials.actualId, "a1")
        XCTAssertEqual(Credentials.sittingId, "s1")
    }

    func testPickerFromSavedKeepsCurrentIds() {
        let list = [
            CalendarSummary(id: "p-new", summary: "PLAN"),
            CalendarSummary(id: "a-new", summary: "ACTUAL"),
            CalendarSummary(id: "s-new", summary: "SITTING"),
        ]
        let pick = CalendarAPI.Pick.fromSaved(list)
        XCTAssertEqual(pick.planId, "p1")
        XCTAssertEqual(pick.actualId, "a1")
        XCTAssertEqual(pick.sittingId, "s1")
        XCTAssertNotEqual(pick.actualId, "a-new")
    }

    func testNoLockServiceOrCrossDeviceLock() throws {
        let ios = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TimeTap")
        var hits: [String] = []
        let walker = FileManager.default.enumerator(at: ios, includingPropertiesForKeys: nil)!
        while let url = walker.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains("LockService") || text.contains("cross-device lock")
                || text.contains("crossDeviceLock") {
                hits.append(url.lastPathComponent)
            }
        }
        XCTAssertTrue(hits.isEmpty, "lock found in \(hits)")
    }
}
