import XCTest
@testable import TimeTap

@MainActor
final class C3Tests: TimeTapTestCase {
    let actual = FakeCalendar()
    let sitting = FakeCalendar()
    let t0: Double = 1_700_000_000_000
    var t: Double = 0

    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
        t = t0
        ApplyOps.nowMs = t0
        ApplyOps.actual = actual
        ApplyOps.sitting = sitting
        ApplyOps.timeZone = TimeZone(secondsFromGMT: 0)!
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }

    override func tearDown() {
        ApplyOps.resetForTests()
        super.tearDown()
    }

    func testCaptureParityMatchesB2B3Writer() async {
        let store = wiredStore()
        store.tapCategory("DW")
        await store.flushNow()
        XCTAssertEqual(actual.events.count, 1)
        XCTAssertEqual(actual.events[0].title, "DW:")
        XCTAssertTrue(actual.events[0].description.contains("#open"))
        XCTAssertEqual(actual.events[0].colorId, "9")

        t += 60_000
        store.tapCategory("MTG")
        await store.flushNow()
        let dw = actual.events.first { $0.title.hasPrefix("DW") }!
        let mtg = actual.events.first { $0.title.hasPrefix("MTG") }!
        XCTAssertEqual(dw.title, "DW:")
        XCTAssertFalse(dw.description.contains("#open"))
        XCTAssertEqual(dw.endMs, t)
        XCTAssertEqual(dw.colorId, "9")
        XCTAssertEqual(mtg.title, "MTG:")
        XCTAssertEqual(mtg.colorId, "3")
        XCTAssertTrue(mtg.description.contains("#open"))
        XCTAssertEqual(actual.events.filter { $0.description.contains("#open") }.count, 1)

        store.takeUndo()
        await store.flushNow()
        XCTAssertNil(actual.events.first { $0.title.hasPrefix("MTG") })
        XCTAssertTrue(actual.events.contains { $0.title.hasPrefix("DW") && $0.description.contains("#open") })
        XCTAssertFalse(actual.events[0].title.contains("="))
        XCTAssertEqual(store.open?.key, "DW")

        t += 60_000
        store.toggleSit()
        await store.flushNow()
        XCTAssertEqual(sitting.events.count, 1)
        XCTAssertEqual(sitting.events[0].title, "SIT")
        XCTAssertTrue(sitting.events[0].description.contains("#open"))

        t += 60_000
        store.openSplit()
        store.setSplitWhole(false)
        store.setSplitMinutes(1)
        store.doSplit(key: "ADM")
        await store.flushNow()
        let splitAt = t0 + 60_000
        let dwHalf = actual.events.first { $0.title.hasPrefix("DW") }!
        let adm = actual.events.first { $0.title.hasPrefix("ADM") }!
        XCTAssertFalse(dwHalf.description.contains("#open"))
        XCTAssertEqual(dwHalf.endMs, splitAt)
        XCTAssertEqual(adm.title, "ADM:")
        XCTAssertEqual(adm.colorId, "8")
        XCTAssertTrue(adm.description.contains("#open"))
        XCTAssertEqual(adm.startMs, splitAt)
        XCTAssertEqual(actual.events.filter { $0.description.contains("#open") }.count, 1)
        XCTAssertEqual(store.open?.key, "ADM")

        store.openSplit()
        store.setSplitWhole(true)
        store.doSplit(key: "BODY")
        await store.flushNow()
        XCTAssertEqual(store.open?.key, "BODY")
        XCTAssertEqual(actual.events.count, 2)
        XCTAssertFalse(actual.events.contains { $0.title.hasPrefix("ADM") })
        let body = actual.events.first { $0.description.contains("#open") }!
        XCTAssertEqual(body.title, "BODY:")
        XCTAssertEqual(body.colorId, "10")
        XCTAssertEqual(body.startMs, splitAt)

        store.noteDelayNs = 1_000
        store.noteChanged("memo")
        try? await Task.sleep(nanoseconds: 20_000_000)
        await store.flushNow()
        XCTAssertEqual(
            actual.events.first { $0.description.contains("#open") }?.title,
            "BODY: memo"
        )

        store.markStrip = .init(
            ref: store.open!.ref, key: store.open!.key,
            durMs: 20 * 60_000, hintMs: store.open!.startMs
        )
        store.applyMark("-")
        await store.flushNow()
        XCTAssertEqual(
            actual.events.first { $0.description.contains("#open") }?.title,
            "BODY: memo -"
        )

        t += 60_000
        let stopAt = t
        store.endDay()
        await store.flushNow()
        XCTAssertFalse(actual.events.contains { $0.description.contains("#open") })
        XCTAssertFalse(sitting.events.contains { $0.description.contains("#open") })
        XCTAssertEqual(actual.events.count, 2)
        let dwDone = actual.events.first { $0.title.hasPrefix("DW") }!
        let bodyDone = actual.events.first { $0.title.hasPrefix("BODY") }!
        XCTAssertEqual(dwDone.title, "DW:")
        XCTAssertEqual(dwDone.endMs, splitAt)
        XCTAssertEqual(bodyDone.title, "BODY: memo +")
        XCTAssertEqual(bodyDone.endMs, stopAt)
        XCTAssertEqual(sitting.events.count, 1)
        XCTAssertEqual(sitting.events[0].title, "SIT")
        XCTAssertEqual(sitting.events[0].endMs, stopAt)
        XCTAssertNil(store.open)
        XCTAssertNil(store.sit)
    }

    func testRailHasUnloggedGap() {
        let store = wiredStore()
        store.today = [
            TodayBlock(ref: "a", key: "DW", startMs: t0, endMs: t0 + 60_000),
            TodayBlock(ref: "b", key: "MTG", startMs: t0 + 180_000, endMs: t0 + 240_000),
        ]
        let (_, items) = store.railItems(budget: 400, now: t0 + 240_000)
        XCTAssertTrue(items.contains { $0.isGap && $0.name == "UNLOGGED" })
        XCTAssertGreaterThan(items.first { $0.isGap }!.ms, 90_000)
    }

    func testUnreadableOpenDoesNotLightADM() async {
        let ev = actual.createEvent(
            calendarId: "a1", title: "Lunch with Ada",
            startMs: t0, endMs: t0 + 60_000
        )
        ev.description = "#ref:lunchlunchlunch1\n#open"
        ApplyOps.nowMs = t0 + 30_000
        let store = wiredStore()
        await store.bootNow()
        XCTAssertEqual(store.open?.key, "UNFILED")
        XCTAssertNotEqual(store.open?.key, "ADM")
        XCTAssertTrue(store.unreadableOpen)
        XCTAssertTrue(store.banner?.contains("cannot read") == true)
        XCTAssertFalse(store.categories.contains { $0.key == store.open?.key })
    }

    private func wiredStore() -> TapStore {
        let store = TapStore()
        store.clock = { [weak self] in
            guard let self else { return Date().timeIntervalSince1970 * 1000 }
            ApplyOps.nowMs = self.t
            return self.t
        }
        return store
    }
}
