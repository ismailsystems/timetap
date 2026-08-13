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
        XCTAssertTrue(text.contains("showNoteField"), "note field must hide when idle")
        XCTAssertTrue(text.contains("\"ADD NOTE\""), "empty note is a button, not an empty field")
        XCTAssertTrue(text.contains("beginNoteEdit()"), "ADD NOTE and the rail still open the field")
        XCTAssertTrue(text.contains("showAddNote"), "a saved note hides ADD NOTE")
        XCTAssertTrue(text.contains("addNoteButton"), "ADD NOTE sits beside the duration")
        XCTAssertTrue(text.contains("editingNote || focus == .note"), "the field stays up only while editing")
        let nowPanel = text[
            text.range(of: "private var nowPanel")!.lowerBound
                ..< text.range(of: "private var settingsButton")!.lowerBound
        ]
        XCTAssertTrue(nowPanel.contains("addNoteButton"), "ADD NOTE is on the duration row")
        XCTAssertTrue(nowPanel.contains("noteField"), "the field still opens under the duration")
        XCTAssertLessThan(
            nowPanel.range(of: "headerActions")!.lowerBound,
            nowPanel.range(of: "noteField")!.lowerBound,
            "note field spans under STOP and SPLIT"
        )
        XCTAssertTrue(text.contains("if let banner = store.banner"), "banner must stay in CaptureView")
        XCTAssertTrue(text.contains("multilineTextAlignment(.center)"), "banner must be centered at the top")
        XCTAssertTrue(text.contains("Text(\"+\")"), "New must be a plus, not a category row")
        XCTAssertFalse(text.contains("face: \"ADD\""), "ADD label is back")
        XCTAssertFalse(text.contains("face: \"New\""), "New text label is back")
        XCTAssertTrue(text.contains("STANDING"), "idle sit names standing, like the Live Activity")
        XCTAssertFalse(text.contains("TAP TO SIT"), "idle sit is standing, not a prompt")
        XCTAssertTrue(text.contains("outlineChip(\"SPLIT\""))
        XCTAssertTrue(text.contains("outlineChip(\"STOP\""))
        XCTAssertTrue(text.contains("store.endDay()"))
        XCTAssertTrue(text.contains("headerActions"))
        XCTAssertFalse(text.contains("gridCellColumns"), "sit is not in the SPLIT/STOP cluster")
        let header = text[
            text.range(of: "private var headerActions")!.lowerBound
                ..< text.range(of: "private var splitButton")!.lowerBound
        ]
        XCTAssertTrue(header.contains("VStack"), "STOP stacks above SPLIT")
        XCTAssertLessThan(
            header.range(of: "stopButton")!.lowerBound,
            header.range(of: "splitButton")!.lowerBound,
            "STOP sits above SPLIT"
        )
        XCTAssertLessThan(
            text.range(of: "headerActions")!.lowerBound,
            text.range(of: "private var footer")!.lowerBound
        )
        let footer = text[
            text.range(of: "private var footer")!.lowerBound
                ..< text.range(of: "private var elapsedLabel")!.lowerBound
        ]
        XCTAssertFalse(footer.contains("sitChip"), "footer must not keep a sitting row")
        XCTAssertFalse(footer.contains("TAP TO SIT"), "footer must not keep TAP TO SIT")
        XCTAssertFalse(
            text.contains("store.open != nil || store.sit != nil"),
            "STOP must not appear for sitting alone"
        )
        XCTAssertTrue(text.contains("Does not stop sitting"))
        XCTAssertTrue(text.contains("SITTING"), "sitting chip keeps its name")
        XCTAssertTrue(text.contains("postureElapsed"), "sit and stand duration live inside the chip")
        XCTAssertFalse(
            text.contains("Button(action: store.openSitEdit)"),
            "sitting chip must be one button, not a stop control plus a clock"
        )
        XCTAssertTrue(text.contains("Adjust sitting start"), "long press still opens sit edit")
        XCTAssertTrue(text.contains("offset(y: -1)"), "+ must sit on the visual centre of the add row")
        XCTAssertFalse(
            text.contains("padding(.trailing, 8)"),
            "sit duration must not sit next to STOP as its own chip"
        )
        XCTAssertTrue(text.contains("MARK IT"), "mark row must name the closed block")
        XCTAssertTrue(text.contains("padding(.bottom, 12)"), "UNDO must sit off the sit row")
        XCTAssertTrue(text.contains("categoryList(height:"), "category column must know its height")
        XCTAssertGreaterThanOrEqual(
            text.components(separatedBy: "overlay(alignment: .bottom)").count - 1,
            2,
            "dual column must close with the same bottom rule as the now panel"
        )
        XCTAssertTrue(text.contains("minHeight: 44") || text.contains("max(44"), "category rows need a 44pt floor")
        XCTAssertTrue(text.contains("Theme.postureSymbol"), "in-app sit uses the Live Activity figures")
        let sitBody = text[
            text.range(of: "private var sitChip")!.lowerBound
                ..< text.range(of: "private func outlineChip")!.lowerBound
        ]
        XCTAssertFalse(sitBody.contains("strokeBorder"), "sit is a list row, not a boxed chip")
        XCTAssertTrue(sitBody.contains("STANDING"), "not sitting names standing")
        XCTAssertTrue(sitBody.contains("postureElapsed"), "standing still shows a duration")
        XCTAssertTrue(sitBody.contains(".background(Theme.panel)"), "posture row always looks selected")
        XCTAssertFalse(sitBody.contains("Theme.mute"), "idle posture is not a muted prompt")
        XCTAssertFalse(sitBody.contains("Color.clear"), "idle posture keeps the selected fill")
        XCTAssertTrue(sitBody.contains(".isSelected"), "VoiceOver always treats posture as on")
        let add = text.range(of: "if store.canAddCategory")!
        let forEach = text.range(of: "ForEach(store.categories)")!
        let sit = text.range(of: "sitChip")!
        XCTAssertLessThan(add.lowerBound, forEach.lowerBound, "+ must sit on top of the category list")
        XCTAssertLessThan(forEach.lowerBound, sit.lowerBound, "sit must sit under the category list")
        XCTAssertTrue(text.contains("Theme.font("), "capture type must scale")
        XCTAssertTrue(text.contains("running: store.open?.key == cat.key"), "running row must show elapsed")
        XCTAssertFalse(
            text.contains("Rectangle().fill(Theme.accent).frame(width: 4)"),
            "running category must not keep a red leading bar"
        )
        XCTAssertTrue(text.contains("openDeadDrawer()"), "SET ASIDE must open the set-aside list")
        XCTAssertTrue(text.contains("gearshape"), "settings gear replaces the sync label")
        XCTAssertTrue(text.contains("store.showSettings = true"), "gear opens settings")
        XCTAssertFalse(text.contains("GOOGLE CALENDAR"), "sync status is not a calendar label")
        XCTAssertFalse(text.contains("Text(store.syncLabel)"), "sync status sits on the rail, not in the now panel")
        XCTAssertFalse(text.contains("nowKick"), "nowKick is gone")
        XCTAssertTrue(text.contains("minimumScaleFactor(0.6)"), "Deep work must shrink before it ellipsizes")
        XCTAssertFalse(text.contains("ActivityKit"), "Live Activity stays off the capture canvas")
        XCTAssertFalse(text.contains("LiveActivity"), "Live Activity stays off the capture canvas")
    }

    func testLiveActivityHasSitAndStopButtons() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTapWidget/RunningBlockLiveActivity.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("ToggleSitIntent"))
        XCTAssertTrue(text.contains("StopBlockIntent"))
        XCTAssertTrue(text.contains("Button(intent:"))
        XCTAssertTrue(text.contains("DynamicIslandExpandedRegion(.bottom)"))
        XCTAssertTrue(text.contains("StopSitIntent"))
        XCTAssertTrue(text.contains("postureTimerRange"))
        XCTAssertTrue(text.contains("sittingRow"))
        XCTAssertTrue(text.contains("\"STOP\""))
        XCTAssertTrue(text.contains("\"START\""))
        XCTAssertTrue(text.contains("Theme.postureSymbol"))
        XCTAssertTrue(text.contains("NOT SITTING"))
        XCTAssertTrue(text.contains("islandBlock"), "Island left is the running category and its duration")
        XCTAssertTrue(text.contains("islandPosture"), "Island right is sitting or not sitting and that duration")
        let elapsed = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/LiveActivity/ElapsedTimer.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            elapsed.contains("frame(width: width, height: size + 4, alignment: align)"),
            "Island timers must not claim a huge slot"
        )
        XCTAssertTrue(elapsed.contains(".clipped()"), "timerInterval overflows its frame unless clipped")
        XCTAssertTrue(text.contains("ElapsedTimer("), "Live Activity must host ElapsedTimer")
        XCTAssertTrue(text.contains("\"STANDING\"") || text.contains("STANDING"), "compact right names standing")
        XCTAssertTrue(text.contains("compactLeading"))
        XCTAssertTrue(text.contains("compactTrailing"))
        XCTAssertTrue(text.contains("padding(.leading, 8)"), "compact left inset from the island cap")
        XCTAssertTrue(text.contains("padding(.trailing, 8)"), "compact right inset from the island cap")
        XCTAssertTrue(text.contains("Text(verbatim:"))
        XCTAssertFalse(text.contains("sitDot"), "red sit dot must be a figure icon")
        XCTAssertTrue(
            text.contains("verbatim: state.sitting ? \"SITTING\" : \"NOT SITTING\""),
            "lock screen posture row must always name sitting or not sitting"
        )
        XCTAssertFalse(text.contains("frame(width: 4)"), "Live Activity must not add a red strip beside the category bar")
        XCTAssertFalse(text.contains("keylineTint"), "Island keyline is a second red edge")
        XCTAssertFalse(text.contains("progressViewStyle"), "Live Activity must not become a timer ring")
        let theme = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Theme.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(theme.contains("figure.stand"))
        XCTAssertTrue(theme.contains("figure.seated.side.right"))
    }

    func testPostureTimerUsesStandStartWhenNotSitting() {
        let sit = RunningBlockAttributes.ContentState(
            sitting: true, sitStartMs: 1_700_000_000_000
        )
        XCTAssertNotNil(sit.postureTimerRange)
        XCTAssertNotNil(sit.sitTimerRange)
        let stand = RunningBlockAttributes.ContentState(
            sitting: false, standStartMs: 1_700_000_060_000
        )
        XCTAssertNotNil(stand.postureTimerRange)
        XCTAssertNil(stand.sitTimerRange)
    }

    func testLiveActivityIntentsRunWithoutUnlock() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/LiveActivity/RunningBlockIntents.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("authenticationPolicy"))
        XCTAssertTrue(text.contains(".alwaysAllowed"))
        XCTAssertTrue(text.contains("openAppWhenRun: Bool = false") || text.contains("openAppWhenRun = false"))
        XCTAssertTrue(text.contains(".background"))
    }

    func testAppSupportsLiveActivities() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities")
        XCTAssertTrue(
            (raw as? Bool) == true || (raw as? String) == "YES",
            "NSSupportsLiveActivities must be set on the app"
        )
    }

    func testLiveActivityStaysUpWhileStanding() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Services/TapStore.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(
            text.contains("open == nil && sit == nil"),
            "standing still keeps the Live Activity"
        )
        XCTAssertTrue(text.contains("defer { syncLiveActivity() }"), "return to the app must restart a killed Live Activity")
        XCTAssertTrue(text.contains("RunningBlockSync.apply(nil)"), "sign-out still ends the Live Activity")
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
        XCTAssertTrue(text.contains("outlineChip(\"SPLIT\""))
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
        XCTAssertTrue(text.contains("padding(.bottom, 2)"), "NOW ▲ must sit above the footer rule")
        XCTAssertTrue(text.contains("bodyGeo.size.height"), "NOW ▲ keeps its own row so the blocks cannot clip it")
        XCTAssertTrue(text.contains("store.syncLabel"), "sync status sits on the TODAY row")
        XCTAssertTrue(text.contains("multilineTextAlignment(.trailing)"), "sync status is right-justified")
    }

    func testColdStoreDoesNotClaimSynced() {
        GoogleAuth.testHasSession = nil
        let store = TapStore()
        XCTAssertFalse(store.sessionReady)
        XCTAssertTrue(store.syncLabel.contains("waiting"))
        XCTAssertFalse(store.syncLabel.contains("synced"))
    }

    func testSyncStatusIsAShortLabel() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Services/TapStore.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("syncLabel = \"synced\""))
        XCTAssertFalse(text.contains("GOOGLE CALENDAR"))
        XCTAssertFalse(text.contains("NOW · SINCE"))
        XCTAssertFalse(text.contains("now - since"))
        XCTAssertFalse(text.contains("var nowKick"))
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

    func testRailLeadUnloggedWhenTodayIsEmpty() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        ApplyOps.timeZone = TimeZone(secondsFromGMT: 0)!
        let now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        let (label, items) = store.railItems(budget: 400, now: now)
        XCTAssertTrue(label.hasPrefix("TODAY · "))
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].isGap)
        XCTAssertEqual(items[0].name, "UNLOGGED")
        XCTAssertGreaterThan(items[0].ms, 5_000)
    }

    func testRailStartsAtFirstBlockNotMidnight() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        ApplyOps.timeZone = TimeZone(secondsFromGMT: 0)!
        let now: Double = 1_700_000_000_000
        let dayStart = Format.dayStartMs(now)
        let first = dayStart + 9 * 3_600_000
        let store = TapStore()
        store.today = [
            TodayBlock(ref: "a", key: "DW", startMs: first, endMs: first + 120_000)
        ]
        let (label, items) = store.railItems(budget: 400, now: first + 120_000)
        XCTAssertEqual(items.first?.name, "DEEP WORK")
        XCTAssertFalse(items.contains { $0.isGap && $0.ms > 8 * 3_600_000 })
        XCTAssertEqual(label, "TODAY · \(Format.clock(first))")
    }

    func testLavenderPOOPMigratesToBanana() {
        var cfg = ClientConfig.seed
        guard let i = cfg.categories.firstIndex(where: { $0.key == "POOP" }) else {
            return XCTFail("no POOP")
        }
        cfg.categories[i].color = "1"
        cfg.categories[i].hex = "#7986cb"
        let out = TapStore.migrateSeedColors(cfg)
        XCTAssertEqual(out.categories[i].color, "5")
        XCTAssertEqual(out.categories[i].hex, "#f6bf26")
    }

    func testPersistedLavenderPOOPBecomesBananaOnLoad() {
        var cfg = ClientConfig.seed
        guard let i = cfg.categories.firstIndex(where: { $0.key == "POOP" }) else {
            return XCTFail("no POOP")
        }
        cfg.categories[i].color = "1"
        cfg.categories[i].hex = "#7986cb"
        if let data = try? JSONEncoder().encode(cfg) {
            UserDefaults.standard.set(data, forKey: "tt.config.v1")
        }
        GoogleAuth.testHasSession = false
        let store = TapStore()
        let poop = store.categories.first { $0.key == "POOP" }
        XCTAssertEqual(poop?.color, "5")
        XCTAssertEqual(poop?.hex, "#f6bf26")
    }

    func testSetAsideDoesNotClaimRetryingWhenQueueIsEmpty() {
        if let data = try? JSONEncoder().encode([
            DeadEntry(
                at: 1_700_000_000_000,
                why: "insert failed",
                op: Op(id: "o1", type: "openActual", ref: "abcdefghijklmnop", key: "DW"),
                key: "DW",
                startMs: 1_700_000_000_000
            )
        ]) {
            UserDefaults.standard.set(data, forKey: "tt.dead.v1")
        }
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        let store = TapStore()
        store.discardDead(token: "nope")
        XCTAssertEqual(store.syncLabel, "1 set aside")
        XCTAssertFalse(store.syncLabel.contains("retrying"))
        XCTAssertNotNil(store.banner)
    }

    func testPersistedTodaySurvivesRelaunch() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("DW")
        now += 60_000
        store.endDay()
        XCTAssertEqual(store.today.first?.key, "DW")
        let again = TapStore()
        XCTAssertEqual(again.today.first?.key, "DW")
        XCTAssertEqual(again.today.first?.endMs, now)
    }

    func testEndDayLeavesSittingRunning() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("DW")
        now += 1_000
        store.toggleSit()
        now += 60_000
        store.endDay()
        XCTAssertNil(store.open)
        XCTAssertNotNil(store.sit)
        XCTAssertFalse(store.queue.contains { $0.type == "closeSit" })
        store.stopSit()
        XCTAssertNil(store.sit)
        XCTAssertTrue(store.queue.contains { $0.type == "closeSit" })
    }

    func testPatch404PostsTheEvent() async {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        let t: Double = 1_700_000_000_000
        ApplyOps.nowMs = t + 120_000
        let open = CalEvent(
            id: "gid-old", calendarId: "a1", key: "DW", title: "DW:",
            colorId: "9", description: "#ref:abcdefghijklmnop\n#open",
            startMs: t, endMs: t + 60_000
        )
        CalendarAPI.testListedByCal = ["a1": [open], "s1": []]
        CalendarAPI.testPatch404 = true
        if let data = try? JSONEncoder().encode([
            Op(id: "n1", type: "setText", ref: "abcdefghijklmnop", text: "memo")
        ]) {
            UserDefaults.standard.set(data, forKey: "tt.queue.v1")
        }
        let store = TapStore()
        await store.flushNow()
        XCTAssertTrue(
            CalendarAPI.testPushes.contains { $0.method == "PATCH" && $0.eventId == "gid-old" },
            "\(CalendarAPI.testPushes)"
        )
        XCTAssertTrue(
            CalendarAPI.testPushes.contains { $0.method == "POST" && $0.summary.contains("DW") },
            "PATCH 404 must POST \(CalendarAPI.testPushes)"
        )
        XCTAssertTrue(store.queue.isEmpty)
    }

    func testCancelledListedEventsAreSkipped() throws {
        let json = Data("""
        {"items":[
          {"id":"a","status":"cancelled","summary":"DW:","start":{"dateTime":"2023-11-14T22:13:20Z"},"end":{"dateTime":"2023-11-14T22:14:20Z"}},
          {"id":"b","status":"confirmed","summary":"MTG:","start":{"dateTime":"2023-11-14T22:13:20Z"},"end":{"dateTime":"2023-11-14T22:14:20Z"}}
        ]}
        """.utf8)
        let evs = try CalendarAPI.listedEvents(from: json, calendarId: "a1")
        XCTAssertEqual(evs.map(\.id), ["b"])
        XCTAssertEqual(evs[0].title, "MTG:")
    }

    func testRetryAfterRaisesTheBackoffFloor() async {
        let dw = "abcdefghijklmnop"
        if let data = try? JSONEncoder().encode([
            Op(id: "o1", type: "openActual", ref: dw, key: "DW", startMs: 1_700_000_000_000)
        ]) {
            UserDefaults.standard.set(data, forKey: "tt.queue.v1")
        }
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        ApplyOps.actual = FakeCalendar()
        ApplyOps.sitting = FakeCalendar()
        let store = TapStore()
        CalendarAPI.testRetryAfter = 10
        CalendarAPI.testStatusQueue = [429]
        await store.flushNow()
        XCTAssertEqual(store.retryDelay, 20)
        XCTAssertEqual(store.queue.map(\.id), ["o1"])
    }

    func testOnFillUsesDarkTextOnPaleBlocks() {
        XCTAssertEqual(Theme.onFill("#f6bf26"), Theme.ground)
        XCTAssertEqual(Theme.onFill("#e67c73"), Theme.ground)
        XCTAssertEqual(Theme.onFill("#f4511e"), Theme.ground)
        XCTAssertNotEqual(Theme.onFill("#3f51b5"), Theme.ground)
    }

    func testClockUsesApplyOpsTimeZone() {
        ApplyOps.timeZone = TimeZone(identifier: "America/Chicago")!
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 15; c.hour = 10; c.minute = 5
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = ApplyOps.timeZone
        let ms = cal.date(from: c)!.timeIntervalSince1970 * 1000
        XCTAssertEqual(Format.clock(ms), "10:05 AM")
        XCTAssertEqual(Format.dayStartMs(ms), cal.startOfDay(for: cal.date(from: c)!).timeIntervalSince1970 * 1000)
    }

    func testSitDeleteArmsLikeDiscard() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/SitEditSheet.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("TAP AGAIN TO DELETE"))
        XCTAssertTrue(text.contains("0.3"))
        XCTAssertTrue(text.contains("armOrDelete"))
    }

    func testPickerLoadRefreshesOnceOn401() async {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        CalendarAPI.testListError = CalendarHTTPError(status: 401)
        let store = TapStore()
        let before = GoogleAuth.refreshCount
        let first = await store.loadCalendars()
        XCTAssertEqual(GoogleAuth.refreshCount, before + 1)
        if case .failure(let err as CalendarHTTPError) = first {
            XCTAssertEqual(err.status, 401)
        } else {
            XCTFail("second 401 must fail")
        }
        XCTAssertTrue(store.showSignIn)
    }

    func testConfirmCalendarsFlushesOldIdsBeforeSwitch() async {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        let t: Double = 1_700_000_000_000
        ApplyOps.nowMs = t + 120_000
        let open = CalEvent(
            id: "gid-a1", calendarId: "a1", key: "DW", title: "DW:",
            colorId: "9", description: "#ref:abcdefghijklmnop\n#open",
            startMs: t, endMs: t + 60_000
        )
        CalendarAPI.testListedByCal = ["a1": [open], "a2": [], "s1": []]
        var now = t + 120_000
        let store = TapStore()
        store.clock = { now }
        store.open = OpenBlock(ref: "abcdefghijklmnop", key: "DW", startMs: t)
        await store.confirmCalendars(plan: "p1", actual: "a2", sitting: "s1")
        XCTAssertEqual(Credentials.actualId, "a2")
        XCTAssertTrue(
            CalendarAPI.testPushes.contains { $0.calendarId == "a1" },
            "close must hit the old calendar \(CalendarAPI.testPushes)"
        )
        XCTAssertNil(store.open)
    }
}
