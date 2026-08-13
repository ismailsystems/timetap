import XCTest
@testable import TimeTap

@MainActor
final class C1Tests: XCTestCase {
    let actual = FakeCalendar()
    let sitting = FakeCalendar()
    let t: Double = 1_700_000_000_000
    let dw = "abcdefghijklmnop"

    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
        ApplyOps.nowMs = t + 3_600_000
        ApplyOps.actual = actual
        ApplyOps.sitting = sitting
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

    func testSuccessfulFlushLeavesQueueAndSkipsTimetapAPI() async throws {
        seedQueue([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let store = TapStore()
        XCTAssertEqual(store.queue.map(\.id), ["o1"])
        await store.flushNow()
        XCTAssertTrue(store.queue.isEmpty, "applied ids must leave the queue")
        XCTAssertEqual(actual.events.count, 1)
        XCTAssertEqual(actual.events[0].title, "DW:")
        XCTAssertTrue(CalendarAPI.didFlush)
        XCTAssertFalse(store.syncLabel.contains("SYNCED") && store.syncFailed)
        XCTAssertEqual(store.syncLabel, "GOOGLE CALENDAR · SYNCED")
        try assertNoTimetapAPI()
    }

    func testRejectedOpenActualGoesDeadAfterFiveFlushes() async {
        seedQueue([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let store = TapStore()
        store.open = OpenBlock(ref: dw, key: "DW", startMs: t)
        CalendarAPI.rejectWrites = true
        for _ in 1...5 { await store.flushNow() }
        XCTAssertTrue(store.queue.isEmpty, "dead-lettered op must leave the queue")
        XCTAssertEqual(store.dead.count, 1)
        XCTAssertEqual(store.dead[0].op.id, "o1")
        XCTAssertEqual(store.dead[0].op.type, "openActual")
        XCTAssertNil(store.open, "grid must not show the failed open as running")
        XCTAssertFalse(store.syncLabel.contains("SYNCED"))
    }

    func testSetAsideSetMarkLeavesBlockRunning() async {
        seedQueue([Op(id: "m1", type: "setMark", ref: dw, mark: "-", hintMs: t)])
        let store = TapStore()
        store.open = OpenBlock(ref: dw, key: "DW", startMs: t)
        CalendarAPI.rejectWrites = true
        for _ in 1...5 { await store.flushNow() }
        XCTAssertEqual(store.dead.map(\.op.type), ["setMark"])
        XCTAssertEqual(store.open?.ref, dw)
        XCTAssertEqual(store.open?.key, "DW")
    }

    func test401Then200RefreshesOnceAndApplies() async {
        seedQueue([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let store = TapStore()
        CalendarAPI.testStatusQueue = [401, 200]
        await store.flushNow()
        XCTAssertEqual(GoogleAuth.refreshCount, 1)
        XCTAssertTrue(store.queue.isEmpty)
        XCTAssertEqual(actual.events.count, 1)
    }

    func testSecond401DoesNotRefreshInALoop() async {
        seedQueue([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let store = TapStore()
        CalendarAPI.testStatusQueue = [401, 401]
        await store.flushNow()
        XCTAssertEqual(GoogleAuth.refreshCount, 1, "one refresh per flush attempt")
        XCTAssertEqual(store.queue.map(\.id), ["o1"])
        XCTAssertTrue(actual.events.isEmpty)
        let before = GoogleAuth.refreshCount
        CalendarAPI.testStatusQueue = [401, 401]
        await store.flushNow()
        XCTAssertEqual(GoogleAuth.refreshCount, before + 1)
        XCTAssertEqual(store.queue.map(\.id), ["o1"])
    }

    func test429And500BackoffAndStayQueued() async {
        seedQueue([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let store = TapStore()
        XCTAssertEqual(store.retryDelay, 4)
        CalendarAPI.testStatusQueue = [429]
        await store.flushNow()
        XCTAssertEqual(store.queue.map(\.id), ["o1"])
        XCTAssertEqual(store.retryDelay, 8)
        XCTAssertEqual(store.queue.first?.tries, 1)
        CalendarAPI.testStatusQueue = [500]
        await store.flushNow()
        XCTAssertEqual(store.queue.map(\.id), ["o1"])
        XCTAssertEqual(store.retryDelay, 16)
        XCTAssertEqual(store.queue.first?.tries, 2)
        CalendarAPI.testStatusQueue = [500, 500, 500]
        await store.flushNow()
        await store.flushNow()
        await store.flushNow()
        XCTAssertTrue(store.queue.isEmpty)
        XCTAssertEqual(store.dead.map(\.op.id), ["o1"])
    }

    func testAppliedUndoSwitchRunsGetState() async {
        _ = ApplyOps.apply([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t),
            Op(id: "o2", type: "openActual", ref: "mtgmtgmtgmtgmtg1", key: "MTG", startMs: t + 60_000),
        ])
        actual.delete(actual.events.first { $0.description.contains("mtgmtgmtgmtgmtg1") }!)
        let undo = Op(
            id: "u1", type: "undoSwitch", atMs: t + 60_000, nowMs: t + 61_000,
            newRef: "mtgmtgmtgmtgmtg1", prevRef: dw, prevKey: "DW", prevStartMs: t
        )
        let mark = Op(id: "m1", type: "setMark", ref: dw, mark: "=", hintMs: t)
        seedQueue([undo, mark])
        let store = TapStore()
        store.open = OpenBlock(ref: "mtgmtgmtgmtgmtg1", key: "MTG", startMs: t + 60_000)
        XCTAssertEqual(CalendarAPI.getStateCalls, 0)
        await store.flushNow()
        XCTAssertTrue(store.queue.isEmpty)
        XCTAssertEqual(CalendarAPI.getStateCalls, 1)
        XCTAssertEqual(store.open?.key, "DW")
        XCTAssertEqual(store.open?.ref, dw)
        XCTAssertTrue(actual.events.contains { $0.description.contains("#open") && $0.description.contains(dw) })
    }

    func test403IsNotSyncedThenSetAside() async {
        seedQueue([Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: t)])
        let store = TapStore()
        CalendarAPI.testStatusQueue = [403]
        await store.flushNow()
        XCTAssertFalse(store.syncLabel.contains("SYNCED"))
        XCTAssertEqual(store.queue.map(\.id), ["o1"])
        XCTAssertEqual(store.queue.first?.tries, 1)
        XCTAssertTrue(store.dead.isEmpty)
        CalendarAPI.testStatusQueue = [403, 403, 403, 403]
        for _ in 1...4 { await store.flushNow() }
        XCTAssertTrue(store.queue.isEmpty)
        XCTAssertEqual(store.dead.map(\.op.id), ["o1"])
        XCTAssertFalse(store.syncLabel.contains("SYNCED"))
        XCTAssertTrue(actual.events.isEmpty, "403 must not silently drop after applying")
    }

    func testTimeTapSourcesDoNotMentionTimetapAPI() throws {
        try assertNoTimetapAPI()
    }

    private func seedQueue(_ ops: [Op]) {
        if let data = try? JSONEncoder().encode(ops) {
            UserDefaults.standard.set(data, forKey: "tt.queue.v1")
        }
    }

    private func assertNoTimetapAPI() throws {
        let ios = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TimeTap")
        var hits: [String] = []
        let walker = FileManager.default.enumerator(at: ios, includingPropertiesForKeys: nil)!
        while let url = walker.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains("TimetapAPI") { hits.append(url.lastPathComponent) }
        }
        XCTAssertTrue(hits.isEmpty, "TimetapAPI still referenced in \(hits)")
    }
}
