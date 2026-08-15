import XCTest
@testable import TimeTap

final class PlanRailTests: TimeTapTestCase {
    func testPlanTodayKeepsParseableTitlesAndDropsDinner() throws {
        let t: Double = 1_700_000_000_000
        ApplyOps.timeZone = TimeZone(secondsFromGMT: 0)!
        ApplyOps.nowMs = t + 600_000
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        let plan = FakeCalendar()
        _ = plan.createEvent(
            calendarId: "p1", title: "Deep work: memo",
            startMs: t, endMs: t + 1_800_000
        )
        _ = plan.createEvent(
            calendarId: "p1", title: "Dinner",
            startMs: t + 1_800_000, endMs: t + 3_600_000
        )
        ApplyOps.plan = plan
        let st = try ApplyOps.getState()
        XCTAssertEqual(st.planToday?.count, 1)
        XCTAssertEqual(st.planToday?.first?.key, "Deep work")
        XCTAssertEqual(st.planToday?.first?.text, "memo")
        XCTAssertFalse(st.planToday?.contains { $0.key == "Dinner" } == true)
    }

    func testCalendarAPIDoesNotPushDiffToPlan() throws {
        let text = try iosSource("TimeTap/Services/CalendarAPI.swift")
        XCTAssertTrue(
            text.contains("pushDiff(calendarId: Credentials.actualId"),
            "flush still writes ACTUAL"
        )
        XCTAssertTrue(
            text.contains("pushDiff(calendarId: Credentials.sittingId"),
            "flush still writes SITTING"
        )
        XCTAssertFalse(
            text.contains("pushDiff(calendarId: Credentials.planId"),
            "PLAN is read-only; flush must not pushDiff it"
        )
    }

    func testCaptureViewHasPlanAndActualRailsNotACategoryList() throws {
        let text = try iosSource("TimeTap/Views/CaptureView.swift")
        XCTAssertTrue(text.contains("source: .plan"), "left rail is PLAN")
        XCTAssertTrue(text.contains("source: .actual"), "right rail is ACTUAL")
        XCTAssertFalse(text.contains("categoryList"), "category column is gone")
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
