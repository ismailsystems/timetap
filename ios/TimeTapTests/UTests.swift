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
        XCTAssertFalse(text.contains("\"ADD NOTE\""), "ADD NOTE chip is gone")
        XCTAssertTrue(text.contains("beginNoteEdit()"), "the rail and the running-row menu still open the field")
        XCTAssertFalse(text.contains("showAddNote"), "ADD NOTE chip is gone")
        XCTAssertFalse(text.contains("addNoteButton"), "ADD NOTE chip is gone")
        XCTAssertTrue(text.contains("editingNote || focus == .note"), "the field stays up only while editing")
        let titleBar = text[
            text.range(of: "private var titleBar")!.lowerBound
                ..< text.range(of: "private var noteField")!.lowerBound
        ]
        XCTAssertTrue(titleBar.contains("Text(\"TimeTap\")"), "title is TimeTap")
        XCTAssertTrue(titleBar.contains("gearshape"), "gear sits on the title row")
        XCTAssertTrue(titleBar.contains("store.showSettings = true"), "gear opens settings")
        XCTAssertFalse(titleBar.contains("addNoteButton"), "ADD NOTE left the title row")
        XCTAssertTrue(titleBar.contains("noteField"), "the field still opens under the title")
        XCTAssertFalse(titleBar.contains("elapsedLabel"), "elapsed left the title row")
        XCTAssertFalse(titleBar.contains("NOTHING RUNNING"), "running title left the title row")
        XCTAssertFalse(titleBar.contains("headerActions"), "title bar has no STOP/SPLIT column")
        XCTAssertTrue(text.contains("if let banner = store.banner"), "banner must stay in CaptureView")
        XCTAssertTrue(text.contains("multilineTextAlignment(.center)"), "banner must be centered at the top")
        XCTAssertFalse(text.contains("Text(\"+\")"), "add lives in Settings, not on capture")
        XCTAssertFalse(text.contains("face: \"ADD\""), "ADD label is back")
        XCTAssertFalse(text.contains("face: \"New\""), "New text label is back")
        XCTAssertTrue(text.contains("NOT SITTING"), "idle sit names not sitting, like the Live Activity")
        XCTAssertFalse(text.contains("STANDING"), "idle sit must not say STANDING")
        XCTAssertFalse(text.contains("TAP TO SIT"), "idle sit is not a prompt")
        XCTAssertFalse(text.contains("outlineChip(\"SPLIT\""), "SPLIT chip is gone")
        XCTAssertFalse(text.contains("outlineChip(\"STOP\""), "STOP chip is gone")
        XCTAssertFalse(text.contains("headerActions"), "STOP/SPLIT column is gone")
        XCTAssertFalse(text.contains("stopButton"), "STOP chip is gone")
        XCTAssertFalse(text.contains("splitButton"), "SPLIT chip is gone")
        XCTAssertTrue(text.contains("runningCategoryMenu(enabled: running, stop:"), "split is a long press menu on the running row")
        XCTAssertTrue(text.contains("store.openSplit()"), "long press still opens split")
        XCTAssertTrue(text.contains("proposeFromRow"), "tap proposes, then waits 5s")
        XCTAssertTrue(text.contains("store.propose(key)"), "propose still waits 5s")
        XCTAssertFalse(text.contains("gridCellColumns"), "sit is not in a SPLIT/STOP cluster")
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
        XCTAssertFalse(text.contains("private var addRow"), "add row left the capture grid")
        XCTAssertFalse(
            text.contains("padding(.trailing, 8)"),
            "sit duration must not sit next to STOP as its own chip"
        )
        XCTAssertTrue(text.contains("MARK IT"), "mark row must name the closed block")
        XCTAssertTrue(text.contains("CANCEL ·"), "pending cancel sits on the armed row")
        XCTAssertTrue(text.contains("pendingFuse"), "the fuse replaced the bottom bar")
        XCTAssertFalse(text.contains("tt.pendingCancelHit"), "the cancel A/B switch is gone")
        XCTAssertTrue(text.contains("categoryList(height:"), "category column must know its height")
        XCTAssertFalse(
            text.contains("overlay(alignment: .bottom)"),
            "NOW and the dual column have no 2pt bottom rule"
        )
        XCTAssertTrue(text.contains("minHeight: 44") || text.contains("max(44"), "category rows need a 44pt floor")
        XCTAssertTrue(text.contains("Theme.postureSymbol"), "in-app sit uses the Live Activity figures")
        let sitBody = text[
            text.range(of: "private var sitChip")!.lowerBound
                ..< text.range(of: "private func markLabel")!.lowerBound
        ]
        XCTAssertFalse(sitBody.contains("strokeBorder"), "sit is a list row, not a boxed chip")
        XCTAssertTrue(sitBody.contains("NOT SITTING"), "not sitting names not sitting")
        XCTAssertFalse(sitBody.contains("STANDING"), "sit chip must not say STANDING")
        XCTAssertTrue(sitBody.contains("postureElapsed"), "standing still shows a duration")
        XCTAssertTrue(sitBody.contains(".background(Theme.panel)"), "posture row always looks selected")
        XCTAssertFalse(sitBody.contains("Theme.mute"), "idle posture is not a muted prompt")
        XCTAssertFalse(sitBody.contains("Color.clear"), "idle posture keeps the selected fill")
        XCTAssertTrue(sitBody.contains(".isSelected"), "VoiceOver always treats posture as on")
        let forEach = text.range(of: "ForEach(store.groups)")!
        let sit = text.range(of: "sitChip")!
        XCTAssertLessThan(forEach.lowerBound, sit.lowerBound, "sit must sit under the category list")
        XCTAssertFalse(text.contains("settingsRow"), "gear left the category column")
        XCTAssertTrue(text.contains("groups.count + 1"), "groups and sit share one row height")
        XCTAssertTrue(text.contains("gearshape"), "settings gear sits on the title row")
        XCTAssertTrue(text.contains("store.showSettings = true"), "gear opens settings")
        XCTAssertTrue(text.contains("padding(.bottom, 5)"), "dual columns keep a 5pt bottom inset")
        XCTAssertTrue(
            text.contains("min(rowH * CGFloat(store.groups.count), max(0, height - rowH))"),
            "the category scroll must not leave a gap above NOT SITTING"
        )
        XCTAssertTrue(
            text.contains("categoryList(height: geo.size.height)"),
            "category list receives the column height"
        )
        XCTAssertTrue(text.contains("Theme.font("), "capture type must scale")
        XCTAssertTrue(text.contains("group.children.first { $0.label == open.key }"), "running row must show elapsed")
        XCTAssertFalse(
            text.contains("Rectangle().fill(Theme.accent).frame(width: 4)"),
            "running category must not keep a red leading bar"
        )
        XCTAssertTrue(text.contains("openDeadDrawer()"), "SET ASIDE must open the set-aside list")
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
        XCTAssertTrue(text.contains("\"NOT SITTING\"") || text.contains("NOT SITTING"), "compact right names not sitting")
        XCTAssertFalse(text.contains("STANDING"), "Live Activity must not say STANDING")
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
        store.tapCategory("Meetings")
        store.noteChanged("Poop")
        now += 60_000
        let (_, items) = store.railItems(budget: 400, now: now)
        XCTAssertEqual(items.first { $0.isOpen }?.note, "Poop")
        now += 300
        store.tapCategory("Deep work")
        now += 60_000
        let (_, after) = store.railItems(budget: 400, now: now)
        XCTAssertEqual(after.first { $0.name == "MEETINGS" }?.note, "Poop")
    }

    func testSplitIsLongPressOnTheRunningCategory() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/CaptureView.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(text.contains("outlineChip(\"SPLIT\""), "SPLIT chip is gone")
        XCTAssertTrue(text.contains("runningCategoryMenu(enabled: running, stop:"))
        XCTAssertTrue(text.contains("store.openSplit()"))
        XCTAssertTrue(text.contains(".contextMenu"))
        XCTAssertTrue(text.contains("Button(\"Stop\""))
        XCTAssertTrue(text.contains("Button(\"Split\""))
        XCTAssertTrue(text.contains("Button(\"Add note\""))
        XCTAssertFalse(text.contains(".onLongPressGesture(perform: perform)"))
        XCTAssertFalse(text.contains("TAP TO SPLIT"), "mute TAP TO SPLIT chip is back")
        XCTAssertFalse(
            text.contains("if store.open != nil { store.openSplit() }"),
            "title/elapsed must not open SPLIT"
        )
        XCTAssertFalse(text.contains("Dismisses the keyboard"), "elapsed keyboard dismiss left the title")
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
            id: "a", calendarId: "cal", key: "Deep work", title: "Deep work:",
            colorId: "", description: "#ref:abcdefghijklmnop\n#open",
            startMs: t, endMs: t + 60_000
        )
        let body = CalendarAPI.eventBody(empty)
        XCTAssertNil(body["colorId"], "empty colorId is a Google 400")
        XCTAssertEqual(body["start"] as? [String: String], ["dateTime": "2023-11-14T22:13:20Z"])
        let dw = CalEvent(
            id: "a", calendarId: "cal", key: "Deep work", title: "Deep work:",
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
        store.tapCategory("Deep work")
        XCTAssertEqual(store.open?.key, "Deep work")
        now += 100
        store.tapCategory("Meetings")
        XCTAssertEqual(store.open?.key, "Deep work")
        XCTAssertFalse(store.queue.contains { $0.key == "Meetings" })
        now += 300
        store.tapCategory("Meetings")
        XCTAssertEqual(store.open?.key, "Meetings")
    }

    func testSecondSameKeyTapWithin300msDoesNotStop() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("Deep work")
        now += 100
        store.tapCategory("Deep work")
        XCTAssertEqual(store.open?.key, "Deep work")
        XCTAssertNil(store.split)
        XCTAssertEqual(store.queue.filter { $0.type == "openActual" }.count, 1)
        XCTAssertFalse(store.queue.contains { $0.type == "closeActual" })
    }

    func testTapCategorySameKeyCallsEndDayNotOpenSplit() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Services/TapStore.swift"),
            encoding: .utf8
        )
        let start = try XCTUnwrap(text.range(of: "func tapCategory(_ key: String)"))
        let end = try XCTUnwrap(text.range(of: "func retryLastInsert()"))
        XCTAssertLessThan(start.lowerBound, end.lowerBound)
        let tap = text[start.lowerBound..<end.lowerBound]
        XCTAssertTrue(tap.contains("endDay()"), "same-key tap stops")
        XCTAssertFalse(tap.contains("openSplit()"), "same-key tap must not split")
    }

    func testSameKeyTapAfter300msStopsAndLeavesSit() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("Deep work")
        now += 300
        store.toggleSit()
        XCTAssertNotNil(store.sit)
        now += 300
        store.tapCategory("Deep work")
        XCTAssertNil(store.open)
        XCTAssertNotNil(store.sit)
        XCTAssertNil(store.split)
        XCTAssertTrue(store.queue.contains { $0.type == "closeActual" })
        XCTAssertFalse(store.queue.contains { $0.type == "closeSit" })
    }

    func testProposeWaitsCancelAndCommit() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }

        store.propose("Deep work")
        XCTAssertNil(store.open)
        XCTAssertEqual(store.pendingKey, "Deep work")
        XCTAssertFalse(store.pendingStop)
        XCTAssertTrue(store.queue.isEmpty)
        store.takeUndo()
        XCTAssertNil(store.open)
        XCTAssertNil(store.pendingKey)
        XCTAssertTrue(store.queue.isEmpty)

        store.propose("Deep work")
        store.propose("Meetings")
        store.commitPending()
        XCTAssertEqual(store.open?.key, "Meetings")
        XCTAssertNil(store.pendingKey)
        XCTAssertEqual(store.queue.filter { $0.type == "openActual" }.count, 1)

        now += 300
        store.propose("Deep work")
        XCTAssertEqual(store.open?.key, "Meetings")
        XCTAssertEqual(store.pendingKey, "Deep work")
        store.takeUndo()
        XCTAssertEqual(store.open?.key, "Meetings")
        XCTAssertFalse(store.queue.contains { $0.type == "closeActual" })

        now += 300
        store.propose("Meetings")
        XCTAssertTrue(store.pendingStop)
        store.takeUndo()
        XCTAssertEqual(store.open?.key, "Meetings")

        now += 300
        store.propose("Meetings")
        store.commitPending()
        XCTAssertNil(store.open)
        XCTAssertTrue(store.queue.contains { $0.type == "closeActual" })
    }

    func testCancelPendingClearsWithoutApply() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        let store = TapStore()
        store.propose("Deep work")
        XCTAssertEqual(store.pendingKey, "Deep work")
        store.cancelPending()
        XCTAssertNil(store.open)
        XCTAssertNil(store.pendingKey)
        XCTAssertTrue(store.queue.isEmpty)
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
            Op(id: "o1", type: "openActual", ref: dw, key: "Deep work", startMs: ApplyOps.nowMs)
        ]) {
            UserDefaults.standard.set(data, forKey: "tt.queue.v1")
        }
        let store = TapStore()
        await store.flushNow()
        XCTAssertTrue(store.queue.isEmpty)
        XCTAssertTrue(
            CalendarAPI.testPushes.contains { $0.method == "POST" && $0.summary == "Deep work:" },
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
            || text.contains("A category you add in Settings stays on this phone")
        )
        XCTAssertTrue(text.contains("Edit categories"), "the first verb is edit categories")
        XCTAssertTrue(text.contains("CalendarPickerView(embedded: true)"), "the picker is a push")
        XCTAssertFalse(text.contains("showSettings = false"), "settings must stay while calendars open")
        XCTAssertFalse(text.contains("Edit groups and children"), "children is gone from the first screen")
        XCTAssertFalse(text.contains("Section(\"Device\")"), "device status left the first screen")
        XCTAssertTrue(text.contains("presentationDetents"), "the sheet opens at medium")
        let editor = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/CategoryEditor.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(editor.contains("Theme.rowFont(20"), "editor names match capture")
        XCTAssertTrue(editor.contains(".pair(group:"), "a 1:1 rename writes the group and the child")
        XCTAssertTrue(editor.contains("Delete \(name)?") || editor.contains("deleteTitle"), "delete names the row")
    }

    func testCategoryRowStacksGroupOverNameAndKeepsDots() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/CaptureView.swift"),
            encoding: .utf8
        )
        XCTAssertEqual(Theme.typeBump, 1.1, "row type stays 10% over the design size")
        XCTAssertTrue(text.contains("Theme.rowFont(20"), "category names stay 10% over the design size")
        XCTAssertTrue(text.contains("Theme.rowFont(11"), "the group line stays in the same 10% bump")
        XCTAssertTrue(text.contains("VStack(alignment: .leading, spacing: 2)"), "group hangs over the child")
        XCTAssertTrue(text.contains("HStack(alignment: .firstTextBaseline"), "dots sit after the group name")
        XCTAssertTrue(text.contains("ForEach(0..<stops"), "dots still mark how many children you can scrub")
        XCTAssertTrue(text.contains("preview ?? pendingChild"), "finger preview wins the face")
        XCTAssertTrue(text.contains("minimumDistance: 0"), "a tap must still fire onEnded")
        XCTAssertTrue(text.contains("/ 56"), "one child is 56pt")
        XCTAssertTrue(text.contains("((raw % n) + n) % n"), "scrub wraps at both ends")
        XCTAssertTrue(text.contains("cancelPending()"), "scrub back to the open child cancels")
        XCTAssertTrue(text.contains("pendingHere, inChip"), "only the chip cancels")
        XCTAssertTrue(text.contains("chipAteTap"), "the chip tap must win over the row drag")
        XCTAssertTrue(text.contains("running && longPress"), "a long press on the running row does not arm cancel")
        XCTAssertFalse(text.contains("store.rowStyle"), "the A/B row picker is gone")
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
        store.tapCategory("Deep work")
        let start = store.open?.startMs
        now += 5_000
        store.openSplit()
        XCTAssertEqual(store.split?.whole, true)
        store.setSplitWhole(false)
        store.setSplitMinutes(2)
        store.doSplit(key: "Meetings")
        XCTAssertEqual(store.open?.key, "Meetings")
        XCTAssertEqual(store.open?.startMs, start)
        XCTAssertFalse(store.queue.contains { $0.type == "splitActual" })
    }

    func testRailHasNoNowMarker() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/Views/DayRailView.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(text.contains("NOW ▲"), "NOW ▲ left the day rail")
        XCTAssertFalse(text.contains("nowRowHeight"), "NOW row left the day rail")
        XCTAssertFalse(text.contains("\"gearshape\""), "settings gear left the day rail")
        XCTAssertFalse(text.contains("store.showSettings = true"), "settings gear left the day rail")
        XCTAssertTrue(text.contains("store.clock()"))
        XCTAssertTrue(text.contains("dash:"))
        XCTAssertTrue(text.contains("bodyGeo.size.height"), "blocks still fill the rail body")
        XCTAssertTrue(text.contains("store.syncLabel"), "sync status sits on the TODAY row")
        XCTAssertTrue(text.contains("store.syncLabel.uppercased()"), "sync status is all caps")
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
        store.tapCategory("Deep work")
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
        let data = Data(#"{"id":"google-event-1","summary":"Deep work:"}"#.utf8)
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
            TodayBlock(ref: "a", key: "Deep work", startMs: first, endMs: first + 120_000)
        ]
        let (label, items) = store.railItems(budget: 400, now: first + 120_000)
        XCTAssertEqual(items.first?.name, "DEEP WORK")
        XCTAssertFalse(items.contains { $0.isGap && $0.ms > 8 * 3_600_000 })
        XCTAssertEqual(label, "TODAY · \(Format.clock(first))")
    }

    func testLavenderPOOPMigratesToBanana() {
        var cfg = ClientConfig.seed
        guard let gi = cfg.groups.firstIndex(where: { $0.label == "Poop" }) else {
            return XCTFail("no Poop")
        }
        cfg.groups[gi].children[0].color = "1"
        cfg.groups[gi].children[0].hex = "#7986cb"
        let out = TapStore.migrateSeedColors(cfg)
        let poop = out.categories.first { $0.label == "Poop" }
        XCTAssertEqual(poop?.color, "5")
        XCTAssertEqual(poop?.hex, "#f6bf26")
    }

    func testPersistedLavenderPOOPBecomesBananaOnLoad() {
        var cfg = ClientConfig.seed
        guard let gi = cfg.groups.firstIndex(where: { $0.label == "Poop" }) else {
            return XCTFail("no Poop")
        }
        cfg.groups[gi].children[0].color = "1"
        cfg.groups[gi].children[0].hex = "#7986cb"
        if let data = try? JSONEncoder().encode(cfg) {
            UserDefaults.standard.set(data, forKey: "tt.config.v1")
        }
        GoogleAuth.testHasSession = false
        let store = TapStore()
        let poop = store.categories.first { $0.label == "Poop" }
        XCTAssertEqual(poop?.color, "5")
        XCTAssertEqual(poop?.hex, "#f6bf26")
    }

    func testSetAsideDoesNotClaimRetryingWhenQueueIsEmpty() {
        if let data = try? JSONEncoder().encode([
            DeadEntry(
                at: 1_700_000_000_000,
                why: "insert failed",
                op: Op(id: "o1", type: "openActual", ref: "abcdefghijklmnop", key: "Deep work"),
                key: "Deep work",
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
        store.tapCategory("Deep work")
        now += 60_000
        store.endDay()
        XCTAssertEqual(store.today.first?.key, "Deep work")
        let again = TapStore()
        XCTAssertEqual(again.today.first?.key, "Deep work")
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
        store.tapCategory("Deep work")
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
            id: "gid-old", calendarId: "a1", key: "Deep work", title: "Deep work:",
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
            CalendarAPI.testPushes.contains { $0.method == "POST" && $0.summary.contains("Deep work") },
            "PATCH 404 must POST \(CalendarAPI.testPushes)"
        )
        XCTAssertTrue(store.queue.isEmpty)
    }

    func testCancelledListedEventsAreSkipped() throws {
        let json = Data("""
        {"items":[
          {"id":"a","status":"cancelled","summary":"Deep work:","start":{"dateTime":"2023-11-14T22:13:20Z"},"end":{"dateTime":"2023-11-14T22:14:20Z"}},
          {"id":"b","status":"confirmed","summary":"Meetings:","start":{"dateTime":"2023-11-14T22:13:20Z"},"end":{"dateTime":"2023-11-14T22:14:20Z"}}
        ]}
        """.utf8)
        let evs = try CalendarAPI.listedEvents(from: json, calendarId: "a1")
        XCTAssertEqual(evs.map(\.id), ["b"])
        XCTAssertEqual(evs[0].title, "Meetings:")
    }

    func testRetryAfterRaisesTheBackoffFloor() async {
        let dw = "abcdefghijklmnop"
        if let data = try? JSONEncoder().encode([
            Op(id: "o1", type: "openActual", ref: dw, key: "Deep work", startMs: 1_700_000_000_000)
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
            id: "gid-a1", calendarId: "a1", key: "Deep work", title: "Deep work:",
            colorId: "9", description: "#ref:abcdefghijklmnop\n#open",
            startMs: t, endMs: t + 60_000
        )
        CalendarAPI.testListedByCal = ["a1": [open], "a2": [], "s1": []]
        var now = t + 120_000
        let store = TapStore()
        store.clock = { now }
        store.open = OpenBlock(ref: "abcdefghijklmnop", key: "Deep work", startMs: t)
        await store.confirmCalendars(plan: "p1", actual: "a2", sitting: "s1")
        XCTAssertEqual(Credentials.actualId, "a2")
        XCTAssertTrue(
            CalendarAPI.testPushes.contains { $0.calendarId == "a1" },
            "close must hit the old calendar \(CalendarAPI.testPushes)"
        )
        XCTAssertNil(store.open)
    }
}
