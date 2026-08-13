import XCTest
@testable import TimeTap

final class A2Tests: TimeTapTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        CalendarAPI.testList = nil
    }

    func testPreselectsPlanActualSittingByName() {
        let pick = CalendarAPI.Pick.loaded([
            CalendarSummary(id: "p1", summary: "PLAN"),
            CalendarSummary(id: "a1", summary: "ACTUAL"),
            CalendarSummary(id: "s1", summary: "SITTING")
        ])
        XCTAssertEqual(pick.planId, "p1")
        XCTAssertEqual(pick.actualId, "a1")
        XCTAssertEqual(pick.sittingId, "s1")
        XCTAssertTrue(pick.canConfirm)
    }

    func testDuplicateNameTakesFirstMatch() {
        let pick = CalendarAPI.Pick.loaded([
            CalendarSummary(id: "a-old", summary: "ACTUAL"),
            CalendarSummary(id: "a-new", summary: "ACTUAL"),
            CalendarSummary(id: "p1", summary: "PLAN"),
            CalendarSummary(id: "s1", summary: "SITTING")
        ])
        XCTAssertEqual(pick.actualId, "a-old")
        XCTAssertEqual(
            pick.firstMatchRule,
            "If two calendars share a name, the first one in the list is used."
        )
    }

    func testConfirmedIdsAreReadFromDefaultsNotMemory() {
        XCTAssertTrue(CalendarAPI.confirm(plan: "p1", actual: "a1", sitting: "s1"))
        XCTAssertEqual(Credentials.planId, "p1")
        // No in-memory cache: a later defaults write is what reload would see.
        UserDefaults.standard.set("p2", forKey: "calendarPlanId")
        UserDefaults.standard.synchronize()
        XCTAssertEqual(Credentials.planId, "p2")
        XCTAssertEqual(Credentials.actualId, "a1")
        XCTAssertEqual(Credentials.sittingId, "s1")
        XCTAssertTrue(Credentials.hasCalendarIds)
    }

    func testConfirmDisabledUntilSittingChosenByHand() {
        var pick = CalendarAPI.Pick.loaded([
            CalendarSummary(id: "p1", summary: "PLAN"),
            CalendarSummary(id: "a1", summary: "ACTUAL"),
            CalendarSummary(id: "s-hand", summary: "Weekend")
        ])
        XCTAssertEqual(pick.planId, "p1")
        XCTAssertEqual(pick.actualId, "a1")
        XCTAssertNil(pick.sittingId)
        XCTAssertFalse(pick.canConfirm)
        XCTAssertFalse(CalendarAPI.confirm(plan: pick.planId, actual: pick.actualId, sitting: pick.sittingId))
        XCTAssertEqual(Credentials.planId, "")
        XCTAssertEqual(Credentials.sittingId, "")
        pick.sittingId = "s-hand"
        XCTAssertTrue(pick.canConfirm)
        XCTAssertTrue(CalendarAPI.confirm(plan: pick.planId, actual: pick.actualId, sitting: pick.sittingId))
        XCTAssertEqual(Credentials.sittingId, "s-hand")
        XCTAssertEqual(Credentials.planId, "p1")
        XCTAssertEqual(Credentials.actualId, "a1")
    }

    func testEmptyListShowsNoCalendarsAndCannotConfirm() {
        let pick = CalendarAPI.Pick.loaded([])
        XCTAssertEqual(pick.emptyLabel, "No calendars")
        XCTAssertFalse(pick.canConfirm)
        XCTAssertFalse(CalendarAPI.confirm(plan: pick.planId, actual: pick.actualId, sitting: pick.sittingId))
        XCTAssertEqual(Credentials.planId, "")
    }
}
