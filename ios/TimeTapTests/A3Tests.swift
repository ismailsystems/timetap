import XCTest
@testable import TimeTap

final class A3Tests: TimeTapTestCase {
    let fake = FakeCalendar()

    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        CalendarAPI.testList = nil
        CalendarAPI.testCalendar = fake
        CalendarAPI.lastPending = nil
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }

    override func tearDown() {
        CalendarAPI.testCalendar = nil
        super.tearDown()
    }

    func testOpenActualDWWritesPath2Event() throws {
        let t: Double = 1_700_000_000_000
        let ev = try CalendarAPI.openActual(key: "DW", at: t, ref: "abcdefghijklmnop")
        XCTAssertEqual(fake.events.count, 1)
        XCTAssertEqual(ev.title, "DW:")
        XCTAssertEqual(ev.colorId, "9")
        XCTAssertNotNil(ev.description.range(of: #"#ref:[A-Za-z0-9]{16}"#, options: .regularExpression))
        XCTAssertTrue(ev.description.contains("#open"))
        XCTAssertEqual(ev.startMs, t)
        XCTAssertEqual(ev.endMs, t + 60_000)
        XCTAssertEqual(ev.calendarId, "a1")
        XCTAssertEqual(fake.lastCalendarId, "a1")
        XCTAssertNotEqual(fake.lastCalendarId, "p1")
        XCTAssertNotEqual(fake.lastCalendarId, "s1")
    }

    func testApplyOpsOpenActualDWWritesPath2Event() {
        let t: Double = 1_700_000_000_000
        ApplyOps.resetForTests()
        ApplyOps.actual = fake
        ApplyOps.sitting = FakeCalendar()
        ApplyOps.nowMs = t
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: "abcdefghijklmnop", key: "DW", startMs: t)
        ])
        XCTAssertEqual(fake.events.count, 1)
        let ev = fake.events[0]
        XCTAssertEqual(ev.title, "DW:")
        XCTAssertEqual(ev.colorId, "9")
        XCTAssertNotNil(ev.description.range(of: #"#ref:[A-Za-z0-9]{16}"#, options: .regularExpression))
        XCTAssertTrue(ev.description.contains("#open"))
        XCTAssertEqual(ev.startMs, t)
        XCTAssertEqual(ev.endMs, t + 60_000)
    }

    func testTapWithoutActualIdDoesNotInsert() async {
        Credentials.actualId = ""
        await MainActor.run {
            let store = TapStore()
            store.tapCategory("DW")
            XCTAssertTrue(fake.events.isEmpty)
            XCTAssertEqual(store.banner, "Pick PLAN, ACTUAL and SITTING calendars first.")
        }
    }

    func testFailedInsertIsNotSyncedAndCanRetry() async {
        fake.failInsert = true
        await MainActor.run {
            let store = TapStore()
            store.tapCategory("DW")
            XCTAssertTrue(fake.events.isEmpty)
            XCTAssertTrue(store.lastInsertFailed)
            XCTAssertFalse(store.syncLabel.contains("SYNCED"))
            fake.failInsert = false
            store.tapCategory("DW")
            XCTAssertEqual(fake.events.count, 1)
            XCTAssertFalse(store.lastInsertFailed)
        }
    }

    func testCaptureWritePathDoesNotCallAppsScript() throws {
        let ios = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let files = [
            "TimeTap/Services/CalendarAPI.swift",
            "TimeTap/Services/TapStore.swift",
            "TimeTap/Views/CaptureView.swift"
        ]
        for rel in files {
            let text = try String(contentsOf: ios.appendingPathComponent(rel), encoding: .utf8)
            XCTAssertFalse(text.contains("script.google.com"), rel)
            XCTAssertFalse(text.contains("macros/s/"), rel)
        }
    }
}
