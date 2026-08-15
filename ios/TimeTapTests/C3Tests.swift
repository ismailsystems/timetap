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
        store.tapCategory("Deep work")
        await store.flushNow()
        XCTAssertEqual(actual.events.count, 1)
        XCTAssertEqual(actual.events[0].title, "Deep work:")
        XCTAssertTrue(actual.events[0].description.contains("#open"))
        XCTAssertEqual(actual.events[0].colorId, "9")

        t += 60_000
        store.propose("Meetings")
        XCTAssertEqual(store.open?.key, "Deep work")
        XCTAssertEqual(store.pendingKey, "Meetings")
        XCTAssertFalse(store.pendingStop)
        store.takeUndo()
        await store.flushNow()
        XCTAssertNil(store.pendingKey)
        XCTAssertNil(actual.events.first { $0.title.hasPrefix("Meetings") })
        XCTAssertTrue(actual.events.contains { $0.title.hasPrefix("Deep work") && $0.description.contains("#open") })
        XCTAssertFalse(actual.events[0].title.contains("="))
        XCTAssertEqual(store.open?.key, "Deep work")

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
        store.doSplit(key: "Admin")
        await store.flushNow()
        let splitAt = t0 + 60_000
        let dwHalf = actual.events.first { $0.title.hasPrefix("Deep work") }!
        let adm = actual.events.first { $0.title.hasPrefix("Admin") }!
        XCTAssertFalse(dwHalf.description.contains("#open"))
        XCTAssertEqual(dwHalf.endMs, splitAt)
        XCTAssertEqual(adm.title, "Admin:")
        XCTAssertEqual(adm.colorId, "8")
        XCTAssertTrue(adm.description.contains("#open"))
        XCTAssertEqual(adm.startMs, splitAt)
        XCTAssertEqual(actual.events.filter { $0.description.contains("#open") }.count, 1)
        XCTAssertEqual(store.open?.key, "Admin")

        store.openSplit()
        store.setSplitWhole(true)
        store.doSplit(key: "Zone 2")
        await store.flushNow()
        XCTAssertEqual(store.open?.key, "Zone 2")
        XCTAssertEqual(actual.events.count, 2)
        XCTAssertFalse(actual.events.contains { $0.title.hasPrefix("Admin") })
        let body = actual.events.first { $0.description.contains("#open") }!
        XCTAssertEqual(body.title, "Zone 2:")
        XCTAssertEqual(body.colorId, "10")
        XCTAssertEqual(body.startMs, splitAt)

        store.noteDelayNs = 1_000
        store.noteChanged("memo")
        try? await Task.sleep(nanoseconds: 20_000_000)
        await store.flushNow()
        XCTAssertEqual(
            actual.events.first { $0.description.contains("#open") }?.title,
            "Zone 2: memo"
        )

        store.markStrip = .init(
            ref: store.open!.ref, key: store.open!.key,
            durMs: 20 * 60_000, hintMs: store.open!.startMs
        )
        store.applyMark("-")
        await store.flushNow()
        XCTAssertEqual(
            actual.events.first { $0.description.contains("#open") }?.title,
            "Zone 2: memo -"
        )

        t += 60_000
        let stopAt = t
        store.endDay()
        await store.flushNow()
        XCTAssertFalse(actual.events.contains { $0.description.contains("#open") })
        XCTAssertTrue(sitting.events.contains { $0.description.contains("#open") })
        XCTAssertEqual(actual.events.count, 2)
        let dwDone = actual.events.first { $0.title.hasPrefix("Deep work") }!
        let bodyDone = actual.events.first { $0.title.hasPrefix("Zone 2") }!
        XCTAssertEqual(dwDone.title, "Deep work:")
        XCTAssertEqual(dwDone.endMs, splitAt)
        XCTAssertEqual(bodyDone.title, "Zone 2: memo +")
        XCTAssertEqual(bodyDone.endMs, stopAt)
        XCTAssertEqual(sitting.events.count, 1)
        XCTAssertEqual(sitting.events[0].title, "SIT")
        XCTAssertNil(store.open)
        XCTAssertNotNil(store.sit)

        t += 60_000
        let sitStopAt = t
        store.stopSit()
        await store.flushNow()
        XCTAssertFalse(sitting.events.contains { $0.description.contains("#open") })
        XCTAssertEqual(sitting.events[0].endMs, sitStopAt)
        XCTAssertNil(store.sit)
    }

    func testRailHasUnloggedGap() {
        let store = wiredStore()
        store.today = [
            TodayBlock(ref: "a", key: "Deep work", startMs: t0, endMs: t0 + 60_000),
            TodayBlock(ref: "b", key: "Meetings", startMs: t0 + 180_000, endMs: t0 + 240_000),
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
        XCTAssertNotEqual(store.open?.key, "Admin")
        XCTAssertTrue(store.unreadableOpen)
        XCTAssertTrue(store.banner?.contains("cannot read") == true)
        XCTAssertFalse(store.categories.contains { $0.label == store.open?.key })
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
