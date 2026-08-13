import XCTest
@testable import TimeTap

@MainActor
final class UTests: TimeTapTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
    }

    func testInitDoesNotFlashSignInWhenSeamIsUnpinned() {
        GoogleAuth.testHasSession = nil
        let store = TapStore()
        XCTAssertFalse(store.showSignIn)
        XCTAssertFalse(store.showPicker)
    }

    func testFreshSplitSliderRangeIsNotAPoint() {
        let t: Double = 1_700_000_000_000
        let range = TapStore.splitSliderRange(startMs: t, nowMs: t)
        XCTAssertEqual(range.lowerBound, 1)
        XCTAssertEqual(range.upperBound, 2)
        XCTAssertGreaterThan(range.upperBound, range.lowerBound)
        let hour = TapStore.splitSliderRange(startMs: t, nowMs: t + 3_600_000)
        XCTAssertEqual(hour.upperBound, 59)
    }

    func testCaptureViewHasNoKeyboardDoneBar() throws {
        let ios = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let text = try String(
            contentsOf: ios.appendingPathComponent("TimeTap/Views/CaptureView.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(text.contains("Button(\"Done\")"), "keyboard Done bar is back")
        XCTAssertFalse(text.contains("axis: .vertical"), "note field must stay single-line so the key is Done")
        XCTAssertTrue(text.contains("showNoteField"), "note field must hide when idle or when a note is already set")
        XCTAssertTrue(text.contains("if let banner = store.banner"), "banner must stay in CaptureView")
        XCTAssertTrue(text.contains("multilineTextAlignment(.center)"), "banner must be centered at the top")
        XCTAssertTrue(text.contains("Text(\"+\")"), "New must be a plus, not a category row")
        XCTAssertFalse(text.contains("face: \"ADD\""), "ADD label is back")
        XCTAssertFalse(text.contains("face: \"New\""), "New text label is back")
        XCTAssertTrue(text.contains("TAP TO SIT"), "idle sit must look tappable")
        XCTAssertTrue(text.contains("outlineChip(\"SPLIT\")"))
        XCTAssertTrue(text.contains("outlineChip(\"STOP\")"))
        XCTAssertTrue(text.contains("MARK IT"), "mark row must name the closed block")
        XCTAssertTrue(text.contains("padding(.bottom, 12)"), "UNDO must sit off TAP TO SIT")
        XCTAssertTrue(text.contains("categoryList(height:"), "category column must know its height")
        XCTAssertTrue(text.contains("minHeight: 44") || text.contains("max(44"), "category rows need a 44pt floor")
    }

    func testOpenBlockNoteShowsOnTheRail() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("MTG")
        store.noteChanged("Poop")
        now += 60_000
        let (_, items) = store.railItems(budget: 400, now: now)
        XCTAssertEqual(items.first { $0.isOpen }?.note, "Poop")
        now += 300
        store.tapCategory("DW")
        now += 60_000
        let (_, after) = store.railItems(budget: 400, now: now)
        XCTAssertEqual(after.first { $0.name == "MEETINGS" }?.note, "Poop")
    }

    func testSplitChipIsTheOnlyOpenSplitControl() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/CaptureView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("outlineChip(\"SPLIT\")"))
        XCTAssertTrue(text.contains("store.openSplit()"))
        XCTAssertFalse(text.contains("TAP TO SPLIT"), "mute TAP TO SPLIT chip is back")
        XCTAssertFalse(
            text.contains("if store.open != nil { store.openSplit() }"),
            "title/elapsed must not open SPLIT"
        )
        XCTAssertTrue(text.contains("Dismisses the keyboard"))
    }

    func testRailLabelSizeGrowsWithTheBlock() {
        XCTAssertGreaterThan(
            DayRailView.labelSize(height: 200, width: 200),
            DayRailView.labelSize(height: 26, width: 200)
        )
        XCTAssertGreaterThanOrEqual(DayRailView.labelSize(height: 10, width: 80), 13)
        XCTAssertLessThanOrEqual(DayRailView.labelSize(height: 400, width: 400), 28)
        XCTAssertTrue(DayRailView.noteInline(height: 24, hasNote: true, size: 13))
        XCTAssertFalse(DayRailView.noteInline(height: 80, hasNote: true, size: 18))
        XCTAssertFalse(DayRailView.noteInline(height: 24, hasNote: false, size: 13))
    }

    func testCalendarWriteBodyOmitsEmptyColorId() {
        let t: Double = 1_700_000_000_000
        let empty = CalEvent(
            id: "a", calendarId: "cal", key: "DW", title: "DW:",
            colorId: "", description: "#ref:abcdefghijklmnop\n#open",
            startMs: t, endMs: t + 60_000
        )
        let body = CalendarAPI.eventBody(empty)
        XCTAssertNil(body["colorId"], "empty colorId is a Google 400")
        XCTAssertEqual(body["start"] as? [String: String], ["dateTime": "2023-11-14T22:13:20Z"])
        let dw = CalEvent(
            id: "a", calendarId: "cal", key: "DW", title: "DW:",
            colorId: "9", description: "#open",
            startMs: t, endMs: t + 60_000
        )
        XCTAssertEqual(CalendarAPI.eventBody(dw)["colorId"] as? String, "9")
    }

    func testCalendarIdEncodesAtSign() {
        XCTAssertEqual(
            CalendarAPI.enc("abc@group.calendar.google.com"),
            "abc%40group.calendar.google.com"
        )
    }

    func testGoogleErrorMessageIsReadable() {
        let data = Data(#"{"error":{"code":400,"message":"Invalid value for: colorId"}}"#.utf8)
        let err = CalendarAPI.googleError(status: 400, data: data)
        XCTAssertEqual(err.localizedDescription, "HTTP 400: Invalid value for: colorId")
    }

    func testSecondTapWithin300msIsIgnored() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("DW")
        XCTAssertEqual(store.open?.key, "DW")
        now += 100
        store.tapCategory("MTG")
        XCTAssertEqual(store.open?.key, "DW")
        XCTAssertFalse(store.queue.contains { $0.key == "MTG" })
        now += 300
        store.tapCategory("MTG")
        XCTAssertEqual(store.open?.key, "MTG")
    }

    func testSecondSameKeyTapWithin300msDoesNotOpenSplit() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("DW")
        now += 100
        store.tapCategory("DW")
        XCTAssertNil(store.split)
        XCTAssertEqual(store.queue.filter { $0.type == "openActual" }.count, 1)
    }

    func testLiveFlushSeamPostsDW() async {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        ApplyOps.nowMs = 1_700_000_000_000
        CalendarAPI.testListedByCal = ["a1": [], "s1": []]
        let dw = "abcdefghijklmnop"
        if let data = try? JSONEncoder().encode([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: ApplyOps.nowMs)
        ]) {
            UserDefaults.standard.set(data, forKey: "tt.queue.v1")
        }
        let store = TapStore()
        await store.flushNow()
        XCTAssertTrue(store.queue.isEmpty)
        XCTAssertTrue(
            CalendarAPI.testPushes.contains { $0.method == "POST" && $0.summary == "DW:" },
            "liveFlush must POST DW: \(CalendarAPI.testPushes)"
        )
    }

    func testSettingsWarnsLastWriteWinsAndExtrasStayOnPhone() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/SettingsView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("last write wins") || text.contains("later write replaces"))
        XCTAssertTrue(
            text.contains("Categories you add here do not appear on the web app.")
            || text.contains("A category you add on the capture grid stays on this phone")
        )
    }

    func testDeadLetterWarnsBeforeDiscard() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/DeadLetterSheet.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("ONLY RECORD IT EVER HAPPENED"))
    }

    func testOpenRailBlockAnnouncesNoteEdit() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/DayRailView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("Edits the note"))
    }

    func testToggleSitWithoutSessionDoesNotEnqueue() {
        GoogleAuth.testHasSession = false
        let store = TapStore()
        store.sessionReady = true
        store.toggleSit()
        XCTAssertTrue(store.showSignIn)
        XCTAssertNil(store.sit)
        XCTAssertTrue(store.queue.isEmpty)
    }

    func testFreshSplitFallsBackToWholeBlock() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("DW")
        let start = store.open?.startMs
        now += 5_000
        store.openSplit()
        XCTAssertEqual(store.split?.whole, true)
        store.setSplitWhole(false)
        store.setSplitMinutes(2)
        store.doSplit(key: "MTG")
        XCTAssertEqual(store.open?.key, "MTG")
        XCTAssertEqual(store.open?.startMs, start)
        XCTAssertFalse(store.queue.contains { $0.type == "splitActual" })
    }

    func testRailKeepsNowMarker() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/DayRailView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("NOW ▲"))
        XCTAssertTrue(text.contains("store.clock()"))
        XCTAssertTrue(text.contains("dash:"))
    }

    func testColdStoreDoesNotClaimSynced() {
        GoogleAuth.testHasSession = nil
        let store = TapStore()
        XCTAssertFalse(store.sessionReady)
        XCTAssertTrue(store.syncLabel.contains("WAITING"))
        XCTAssertFalse(store.syncLabel.contains("SYNCED"))
    }

    func testTapCategoryBeforeSessionReadyDoesNothing() {
        GoogleAuth.testHasSession = nil
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        let store = TapStore()
        store.tapCategory("DW")
        XCTAssertNil(store.open)
        XCTAssertTrue(store.queue.isEmpty)
        XCTAssertFalse(store.showSignIn)
    }

    func testPickerAlwaysHasAWayOut() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/CalendarPickerView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("Sign out"))
        XCTAssertTrue(text.contains("Button(\"Retry\")"))
    }

    func testPostReplyIdIsRead() {
        let data = Data(#"{"id":"google-event-1","summary":"DW:"}"#.utf8)
        XCTAssertEqual(CalendarAPI.createdEventId(from: data), "google-event-1")
        XCTAssertNil(CalendarAPI.createdEventId(from: Data("{}".utf8)))
    }
}
