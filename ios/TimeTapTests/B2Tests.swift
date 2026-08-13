import XCTest
@testable import TimeTap

final class B2Tests: TimeTapTestCase {
    let actual = FakeCalendar()
    let sitting = FakeCalendar()
    let t: Double = 1_700_000_000_000
    let dw = "abcdefghijklmnop"
    let mtg = "mtgmtgmtgmtgmtg1"

    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
        ApplyOps.nowMs = t + 3_600_000
        ApplyOps.actual = actual
        ApplyOps.sitting = sitting
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        GoogleAuth.testHasSession = true
    }

    override func tearDown() {
        ApplyOps.resetForTests()
        super.tearDown()
    }

    func testOpenThenCloseDW() {
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: t + 3_600_000),
        ])
        XCTAssertEqual(actual.events.count, 1)
        let ev = actual.events[0]
        XCTAssertEqual(ev.title, "DW: =")
        XCTAssertFalse(ev.description.contains("#open"))
        XCTAssertEqual(ev.endMs, t + 3_600_000)
        XCTAssertEqual(ev.colorId, "9")
    }

    func testSecondOpenClosesFirst() {
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "o2", type: "openActual", ref: mtg, key: "MTG", startMs: t + 60_000),
        ])
        XCTAssertEqual(actual.events.count, 2)
        let dwEv = actual.events.first { $0.description.contains(dw) }!
        let mtgEv = actual.events.first { $0.description.contains(mtg) }!
        XCTAssertFalse(dwEv.description.contains("#open"))
        XCTAssertEqual(dwEv.endMs, t + 60_000)
        XCTAssertTrue(mtgEv.description.contains("#open"))
        XCTAssertEqual(actual.events.filter { $0.description.contains("#open") }.count, 1)
    }

    func testReplayOpenActualDoesNotDuplicate() {
        let op = Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)
        _ = ApplyOps.apply([op])
        _ = ApplyOps.apply([op])
        XCTAssertEqual(actual.events.count, 1)
    }

    func testAlreadyClosedDoesNotStretch() {
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: t + 3_600_000),
        ])
        let e = actual.events[0].endMs
        _ = ApplyOps.apply([
            Op(id: "c2", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: e + 7_200_000),
        ])
        XCTAssertEqual(actual.events[0].endMs, e)
        XCTAssertEqual(actual.events[0].title, "DW: =")
    }

    func testGuessedCloseDoesMove() {
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let ev = actual.events[0]
        ev.title = Grammar.buildTitle("DW", "", "?")
        ApplyOps.writeDesc(ev, ref: dw, isOpen: false)
        ApplyOps.endEventAt(ev, t + 3_600_000)
        let e = ev.endMs
        _ = ApplyOps.apply([
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: e + 600_000),
        ])
        XCTAssertEqual(actual.events[0].endMs, e + 600_000)
        XCTAssertEqual(actual.events[0].title, "DW: =")
    }

    func testSplitActual() {
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let at = t + 1_800_000
        _ = ApplyOps.apply([
            Op(id: "s1", type: "splitActual", ts: at, ref: dw, mark: "=", atMs: at, nowMs: at + 60_000,
               newRef: mtg, newKey: "MTG"),
        ])
        XCTAssertEqual(actual.events.count, 2)
        let first = actual.events.first { $0.description.contains(dw) }!
        let neu = actual.events.first { $0.description.contains(mtg) }!
        XCTAssertEqual(first.endMs, at)
        XCTAssertFalse(first.description.contains("#open"))
        XCTAssertEqual(neu.startMs, at)
        XCTAssertTrue(neu.description.contains("#open"))
        XCTAssertTrue(neu.title.hasPrefix("MTG:"))
    }

    func testRecategorizeKeepsNoteAndMark() {
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", text: "memo", mark: "=", endMs: t + 60_000),
            Op(id: "r1", type: "recategorize", ref: dw, key: "MTG", hintMs: t),
        ])
        let ev = actual.events[0]
        XCTAssertEqual(ev.title, "MTG: memo =")
        XCTAssertEqual(ev.colorId, "3")
    }

    func testSetTextAndSetMarkOnlyChangeThatField() {
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", text: "memo", mark: "=", endMs: t + 60_000),
        ])
        _ = ApplyOps.apply([Op(id: "t1", type: "setText", ref: dw, text: "other", hintMs: t)])
        XCTAssertEqual(actual.events[0].title, "DW: other =")
        _ = ApplyOps.apply([Op(id: "m1", type: "setMark", ref: dw, mark: "+", hintMs: t)])
        XCTAssertEqual(actual.events[0].title, "DW: other +")
    }

    func testOpenSitThenCloseSit() {
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openSit", ref: dw, startMs: t),
            Op(id: "c1", type: "closeSit", ref: dw, endMs: t + 3_600_000),
        ])
        XCTAssertEqual(sitting.events.count, 1)
        XCTAssertTrue(actual.events.isEmpty)
        let ev = sitting.events[0]
        XCTAssertEqual(ev.title, "SIT")
        XCTAssertFalse(ev.description.contains("#open"))
        XCTAssertEqual(ev.endMs, t + 3_600_000)
    }

    func testLaterCloseSitDoesNotMoveEnd() {
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openSit", ref: dw, startMs: t),
            Op(id: "c1", type: "closeSit", ref: dw, endMs: t + 3_600_000),
        ])
        let e = sitting.events[0].endMs
        _ = ApplyOps.apply([Op(id: "c2", type: "closeSit", ref: dw, endMs: e + 7_200_000)])
        XCTAssertEqual(sitting.events[0].endMs, e)
    }

    func testEndEventAtNeverZeroLength() {
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let ev = actual.events[0]
        ApplyOps.endEventAt(ev, t)
        XCTAssertEqual(ev.endMs, t + 60_000)
        ApplyOps.endEventAt(ev, t - 1)
        XCTAssertEqual(ev.endMs, t + 60_000)
    }

    func testQuestionMarkOpIsDropped() {
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let before = actual.events[0].title
        let r = ApplyOps.apply([
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "?", endMs: t + 3_600_000),
        ])
        XCTAssertEqual(r.dropped?.map(\.id), ["c1"])
        XCTAssertTrue(r.applied?.contains("c1") == true)
        XCTAssertEqual(actual.events[0].title, before)
        XCTAssertTrue(actual.events[0].description.contains("#open"))
    }

    func testUnknownTypeDroppedLaterOpsRun() {
        let r = ApplyOps.apply([
            Op(id: "n1", type: "nope", ref: dw, key: "DW", startMs: t),
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
        ])
        XCTAssertEqual(actual.events.count, 1)
        XCTAssertTrue(r.applied?.contains("n1") == true)
        XCTAssertTrue(r.applied?.contains("o1") == true)
        XCTAssertEqual(actual.events[0].title, "DW:")
    }

    func testNaNEndMsIsDropped() {
        _ = ApplyOps.apply([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let r = ApplyOps.apply([
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: .nan),
        ])
        XCTAssertEqual(r.dropped?.map(\.id), ["c1"])
        XCTAssertTrue(actual.events[0].description.contains("#open"))
    }

    func testOpsRunInArrayOrder() {
        var order: [String] = []
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "c1", type: "closeActual", ref: dw, key: "DW", mark: "=", endMs: t + 60_000),
            Op(id: "o2", type: "openActual", ref: mtg, key: "MTG", startMs: t + 60_000),
        ])
        order = actual.events.map { Grammar.parseTitle($0.title)?.key ?? "" }
        XCTAssertEqual(order, ["DW", "MTG"])
        XCTAssertEqual(actual.events[0].endMs, t + 60_000)
        XCTAssertTrue(actual.events[1].description.contains("#open"))
    }
}
