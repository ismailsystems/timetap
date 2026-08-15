import XCTest
@testable import TimeTap

final class B4Tests: TimeTapTestCase {
    let actual = FakeCalendar()
    let sitting = FakeCalendar()
    let t: Double = 1_700_000_000_000
    let dw = "abcdefghijklmnop"
    let mtg = "mtgmtgmtgmtgmtg1"
    let adm = "admadmadmadmadm1"

    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
        ApplyOps.nowMs = t + 3_600_000
        ApplyOps.actual = actual
        ApplyOps.sitting = sitting
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }

    func testOpenAndTodayDecode() throws {
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "Deep work", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "Deep work", mark: "=", endMs: t + 600_000),
            Op(id: "o2", type: "openActual", ref: mtg, key: "Meetings", startMs: t + 600_000),
            Op(id: "c2", type: "closeActual", ref: mtg, key: "Meetings", mark: "=", endMs: t + 1_200_000),
            Op(id: "o3", type: "openActual", ref: adm, key: "Deep work", startMs: t + 1_200_000),
        ])
        let st = try ApplyOps.getState()
        XCTAssertEqual(st.open?.key, "Deep work")
        XCTAssertEqual(st.today?.count, 2)
        XCTAssertEqual(st.nowMs, ApplyOps.nowMs)
        XCTAssertEqual(st.tz, ApplyOps.timeZone.identifier)
        let data = try JSONEncoder().encode(st)
        let decoded = try JSONDecoder().decode(ServerState.self, from: data)
        XCTAssertEqual(decoded.open?.key, "Deep work")
        XCTAssertEqual(decoded.today?.count, 2)
    }

    func testTwoOpenKeepsNewest() throws {
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "Deep work", startMs: t)])
        let extra = actual.createEvent(
            calendarId: "a1", title: "Meetings:", startMs: t + 60_000, endMs: t + 120_000
        )
        extra.description = "#ref:\(mtg)\n#open"
        extra.colorId = "3"
        let st = try ApplyOps.getState()
        XCTAssertEqual(st.open?.key, "Meetings")
        let dwEv = actual.events.first { $0.description.contains(dw) }!
        XCTAssertFalse(dwEv.description.contains("#open"))
        XCTAssertEqual(dwEv.endMs, t + 60_000)
        XCTAssertEqual(actual.events.filter { ApplyOps.isOpen($0) }.count, 1)
    }

    func testStaleOpenLeavesGuessInToday() throws {
        ApplyOps.timeZone = TimeZone(identifier: "America/Chicago")!
        func local(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Double {
            var c = DateComponents()
            c.year = y; c.month = m; c.day = d; c.hour = h
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = ApplyOps.timeZone
            return cal.date(from: c)!.timeIntervalSince1970 * 1000
        }
        let start = local(2026, 1, 15, 22)
        ApplyOps.nowMs = local(2026, 1, 16, 7)
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "Deep work", startMs: start)])
        let st = try ApplyOps.getState()
        XCTAssertNil(st.open)
        let dwEv = actual.events.first { $0.description.contains(dw) }!
        XCTAssertTrue(dwEv.title.hasSuffix("?"))
        XCTAssertTrue(actual.events.contains { $0.title == "UNLOGGED -" })
        XCTAssertFalse(st.today?.contains { $0.key == "UNLOGGED" } == true)
        XCTAssertTrue(st.today?.isEmpty == true, "GAS overlap window drops the midnight-ending ? block")
    }

    func testLunchIsUnfiledNotAdmin() throws {
        let ev = actual.createEvent(
            calendarId: "a1", title: "Lunch with Ada", startMs: t, endMs: t + 60_000
        )
        ev.description = "#ref:\(dw)\n#open"
        let st = try ApplyOps.getState()
        XCTAssertEqual(st.open?.key, "UNFILED")
        XCTAssertNotEqual(st.open?.key, "Admin")
    }

    func testCalendarReadErrorDoesNotInventIdleDay() {
        ApplyOps.readError = "boom"
        XCTAssertThrowsError(try ApplyOps.getState()) { err in
            guard case ApplyOps.ReadError.calendar(let msg) = err else {
                return XCTFail("wrong error \(err)")
            }
            XCTAssertEqual(msg, "boom")
        }
    }

    func testAllDayEventIgnored() throws {
        let ev = actual.createEvent(
            calendarId: "a1", title: "Deep work:", startMs: t, endMs: t + 86_400_000
        )
        ev.description = "#ref:\(dw)\n#open"
        ev.isAllDay = true
        let st = try ApplyOps.getState()
        XCTAssertNil(st.open)
        XCTAssertTrue(st.today?.isEmpty == true)
    }
}
