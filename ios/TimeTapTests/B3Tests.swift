import XCTest
@testable import TimeTap

final class B3Tests: XCTestCase {
    let actual = FakeCalendar()
    let sitting = FakeCalendar()
    let dw = "abcdefghijklmnop"
    let mtg = "mtgmtgmtgmtgmtg1"
    let sit = "sitsitsitsitsit1"
    let chicago = TimeZone(identifier: "America/Chicago")!

    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
        ApplyOps.actual = actual
        ApplyOps.sitting = sitting
        ApplyOps.timeZone = chicago
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }

    func local(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Double {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = chicago
        return cal.date(from: c)!.timeIntervalSince1970 * 1000
    }

    func testUndoSwitchDeletesNewReopensPrev() {
        let t = local(2026, 1, 15, 10)
        let at = t + 600_000
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: at),
            Op(id: "o2", type: "openActual", ref: mtg, key: "MTG", startMs: at),
        ])
        _ = ApplyOps.apply([
            Op(id: "u1", type: "undoSwitch", atMs: at, nowMs: at + 1_000,
               newRef: mtg, prevRef: dw, prevKey: "DW", prevStartMs: t),
        ])
        XCTAssertNil(actual.events.first { $0.description.contains(mtg) })
        let pe = actual.events.first { $0.description.contains(dw) }!
        XCTAssertTrue(pe.description.contains("#open"))
        XCTAssertFalse(pe.title.contains("="))
        XCTAssertEqual(actual.events.filter { ApplyOps.isOpen($0) }.count, 1)
    }

    func testUndoSwitchOvertakenDoesNotReopen() {
        let t = local(2026, 1, 15, 10)
        let at = t + 600_000
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: at),
            Op(id: "o2", type: "openActual", ref: mtg, key: "MTG", startMs: at),
        ])
        let ne = actual.events.first { $0.description.contains(mtg) }!
        ne.startMs = at + 1
        _ = ApplyOps.apply([
            Op(id: "u1", type: "undoSwitch", atMs: at, nowMs: at + 1_000,
               newRef: mtg, prevRef: dw, prevKey: "DW", prevStartMs: t),
        ])
        XCTAssertNotNil(actual.events.first { $0.description.contains(mtg) })
        let pe = actual.events.first { $0.description.contains(dw) }!
        XCTAssertFalse(pe.description.contains("#open"))
        XCTAssertEqual(actual.events.filter { ApplyOps.isOpen($0) }.count, 1)
    }

    func testUndoStopReopensBlockAndSit() {
        let t = local(2026, 1, 15, 10)
        let at = t + 600_000
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "s1", type: "openSit", ref: sit, startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: at),
            Op(id: "c2", type: "closeSit", ref: sit, endMs: at),
        ])
        let beforeActual = actual.events.count
        _ = ApplyOps.apply([
            Op(id: "u1", type: "undoSwitch", atMs: at, nowMs: at + 1_000,
               newRef: nil, prevRef: dw, prevKey: "DW", prevStartMs: t, sitRef: sit, sitStartMs: t),
        ])
        XCTAssertEqual(actual.events.count, beforeActual)
        XCTAssertTrue(actual.events[0].description.contains("#open"))
        XCTAssertTrue(sitting.events[0].description.contains("#open"))
    }

    func testKillSitRefDeletesNotCloses() {
        let t = local(2026, 1, 15, 10)
        let at = t + 600_000
        let kill = "killkillkillkill"
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: at),
            Op(id: "s1", type: "openSit", ref: kill, startMs: at),
        ])
        _ = ApplyOps.apply([
            Op(id: "u1", type: "undoSwitch", atMs: at, nowMs: at + 1_000,
               newRef: nil, prevRef: dw, prevKey: "DW", prevStartMs: t, killSitRef: kill),
        ])
        XCTAssertTrue(sitting.events.isEmpty)
        XCTAssertTrue(actual.events[0].description.contains("#open"))
    }

    func testStaleOvernightChicagoWritesGuessAndUnlogged() {
        let start = local(2026, 1, 15, 22)
        let now = local(2026, 1, 16, 7)
        ApplyOps.nowMs = now
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: start)])
        let ev = ApplyOps.findOpen(actual)
        _ = ApplyOps.staleGuard(actual, ev, isActual: true)
        let dwEv = actual.events.first { $0.description.contains(dw) }!
        XCTAssertTrue(dwEv.title.hasSuffix("?"))
        XCTAssertFalse(dwEv.title.hasSuffix("="))
        XCTAssertEqual(dwEv.endMs, ApplyOps.addLocalDays(start, 1))
        let un = actual.events.first { $0.title == "UNLOGGED -" }!
        XCTAssertEqual(un.startMs, dwEv.endMs)
        XCTAssertEqual(un.endMs, now)
        XCTAssertNil(ApplyOps.findOpen(actual))
    }

    func testStaleBodyGetsQuestionNotPlus() {
        let start = local(2026, 1, 15, 22)
        let now = local(2026, 1, 16, 7)
        ApplyOps.nowMs = now
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "BODY", startMs: start)])
        _ = ApplyOps.staleGuard(actual, ApplyOps.findOpen(actual), isActual: true)
        XCTAssertTrue(actual.events[0].title.hasSuffix("?"))
        XCTAssertFalse(actual.events[0].title.contains("+"))
    }

    func testFreshOpenAcrossMidnightIsLeftAlone() {
        let start = local(2026, 1, 15, 23, 59) + 55_000
        let now = local(2026, 1, 16, 0, 0) + 5_000
        ApplyOps.nowMs = now
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: start)])
        let left = ApplyOps.staleGuard(actual, ApplyOps.findOpen(actual), isActual: true)
        XCTAssertNotNil(left)
        XCTAssertTrue(actual.events[0].description.contains("#open"))
        XCTAssertEqual(actual.events.count, 1)
    }

    func testStaleSitBoundedNoUnloggedNoQuestion() {
        let start = local(2026, 1, 15, 22)
        let now = local(2026, 1, 16, 7)
        ApplyOps.nowMs = now
        _ = ApplyOps.apply([Op(id: "s1", type: "openSit", ref: sit, startMs: start)])
        _ = ApplyOps.staleGuard(sitting, ApplyOps.findOpen(sitting), isActual: false)
        XCTAssertEqual(sitting.events.count, 1)
        XCTAssertEqual(sitting.events[0].title, "SIT")
        XCTAssertFalse(sitting.events[0].title.contains("?"))
        XCTAssertFalse(sitting.events[0].description.contains("#open"))
        XCTAssertEqual(sitting.events[0].endMs, ApplyOps.addLocalDays(start, 1))
        XCTAssertFalse(sitting.events.contains { $0.title == "UNLOGGED -" })
    }

    func testStopClosesBothOpensNothing() {
        let t = local(2026, 1, 15, 10)
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "s1", type: "openSit", ref: sit, startMs: t),
        ])
        let nA = actual.events.count
        let nS = sitting.events.count
        _ = ApplyOps.apply([
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: t + 60_000),
            Op(id: "c2", type: "closeSit", ref: sit, endMs: t + 60_000),
        ])
        XCTAssertEqual(actual.events.count, nA)
        XCTAssertEqual(sitting.events.count, nS)
        XCTAssertEqual(actual.events[0].endMs, t + 60_000)
        XCTAssertEqual(sitting.events[0].endMs, t + 60_000)
        XCTAssertFalse(actual.events[0].description.contains("#open"))
        XCTAssertFalse(sitting.events[0].description.contains("#open"))
    }

    func testOpenActualDoesNotTouchSitting() {
        let t = local(2026, 1, 15, 10)
        _ = ApplyOps.apply([Op(id: "s1", type: "openSit", ref: sit, startMs: t)])
        let before = sitting.events[0].description
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: mtg, key: "MTG", startMs: t + 60_000)])
        XCTAssertEqual(sitting.events.count, 1)
        XCTAssertEqual(sitting.events[0].description, before)
        XCTAssertTrue(sitting.events[0].description.contains("#open"))
    }

    func testUndoSwitchReplayIsNoOp() {
        let t = local(2026, 1, 15, 10)
        let at = t + 600_000
        let u = Op(id: "u1", type: "undoSwitch", atMs: at, nowMs: at + 1_000,
                   newRef: mtg, prevRef: dw, prevKey: "DW", prevStartMs: t)
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: at),
            Op(id: "o2", type: "openActual", ref: mtg, key: "MTG", startMs: at),
            u, u,
        ])
        XCTAssertEqual(actual.events.filter { $0.description.contains(mtg) }.count, 0)
        XCTAssertEqual(actual.events.filter { ApplyOps.isOpen($0) }.count, 1)
        XCTAssertTrue(actual.events.first { $0.description.contains(dw) }!.description.contains("#open"))
    }
}
