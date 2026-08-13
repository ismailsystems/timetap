import XCTest
@testable import TimeTap

@MainActor
final class LAContractTests: TimeTapTestCase {
    override func tearDown() {
        LiveActivityActions.toggleSit = {}
        LiveActivityActions.stopSit = {}
        LiveActivityActions.endDay = {}
        super.tearDown()
    }

    func testIntentsAreUndiscoverableBackgroundLiveActivityIntents() throws {
        let text = try iosSource("TimeTap/LiveActivity/RunningBlockIntents.swift")
        let toggle = slice(text, from: "struct ToggleSitIntent", to: "struct StopSitIntent")
        let stopSit = slice(text, from: "struct StopSitIntent", to: "struct StopBlockIntent")
        let stopBlock = slice(text, from: "struct StopBlockIntent")
        for body in [toggle, stopSit, stopBlock] {
            XCTAssertTrue(body.contains(": LiveActivityIntent"))
            XCTAssertTrue(
                body.contains("openAppWhenRun = false")
                    || body.contains("openAppWhenRun: Bool = false")
            )
            XCTAssertTrue(body.contains("authenticationPolicy"))
            XCTAssertTrue(body.contains(".alwaysAllowed"))
            XCTAssertTrue(body.contains("@available(iOS 26.0, *)"))
            XCTAssertTrue(body.contains("supportedModes"))
            XCTAssertTrue(body.contains(".background"))
            XCTAssertTrue(
                body.contains("isDiscoverable = false")
                    || body.contains("isDiscoverable: Bool = false")
            )
        }
        XCTAssertTrue(toggle.contains("LiveActivityActions.toggleSit()"))
        XCTAssertTrue(stopSit.contains("LiveActivityActions.stopSit()"))
        XCTAssertTrue(stopBlock.contains("LiveActivityActions.endDay()"))
        XCTAssertFalse(stopBlock.contains("closeSit"))
        XCTAssertFalse(stopBlock.contains("stopSit"))
        XCTAssertFalse(ToggleSitIntent.openAppWhenRun)
        XCTAssertFalse(StopSitIntent.openAppWhenRun)
        XCTAssertFalse(StopBlockIntent.openAppWhenRun)
        XCTAssertFalse(ToggleSitIntent.isDiscoverable)
        XCTAssertFalse(StopSitIntent.isDiscoverable)
        XCTAssertFalse(StopBlockIntent.isDiscoverable)
    }

    func testIntentPerformCallsLiveActivityActions() async throws {
        var toggled = 0
        var stoppedSit = 0
        var endedDay = 0
        LiveActivityActions.toggleSit = { toggled += 1 }
        LiveActivityActions.stopSit = { stoppedSit += 1 }
        LiveActivityActions.endDay = { endedDay += 1 }
        _ = try await ToggleSitIntent().perform()
        XCTAssertEqual(toggled, 1)
        XCTAssertEqual(stoppedSit, 0)
        XCTAssertEqual(endedDay, 0)
        _ = try await StopSitIntent().perform()
        XCTAssertEqual(toggled, 1)
        XCTAssertEqual(stoppedSit, 1)
        XCTAssertEqual(endedDay, 0)
        _ = try await StopBlockIntent().perform()
        XCTAssertEqual(toggled, 1)
        XCTAssertEqual(stoppedSit, 1)
        XCTAssertEqual(endedDay, 1)
    }

    func testAppInitWiresLiveActivityActions() throws {
        let text = try iosSource("TimeTap/TimeTapApp.swift")
        XCTAssertTrue(
            text.contains("LiveActivityActions.toggleSit = { await store.handleSitIntent() }")
        )
        XCTAssertTrue(
            text.contains("LiveActivityActions.stopSit = { await store.handleStopSitIntent() }")
        )
        XCTAssertTrue(
            text.contains("LiveActivityActions.endDay = { await store.handleStopIntent() }")
        )
    }

    func testHandleStopIntentEndsDayWithoutClosingSit() throws {
        let text = try iosSource("TimeTap/Services/TapStore.swift")
        let stop = slice(text, from: "func handleStopIntent()", to: "private func ensureIntentSession()")
        XCTAssertTrue(stop.contains("endDay()"))
        XCTAssertTrue(stop.contains("flushNow()") || stop.contains("flush()"))
        XCTAssertLessThan(
            stop.range(of: "endDay()")!.lowerBound,
            (stop.range(of: "flushNow()") ?? stop.range(of: "flush()")!).lowerBound
        )
        XCTAssertFalse(stop.contains("closeSit"))
        XCTAssertFalse(stop.contains("stopSit"))
        let endDay = slice(text, from: "func endDay()", to: "func toggleSit()")
        XCTAssertFalse(endDay.contains("closeSit"))
        XCTAssertFalse(endDay.contains("stopSit"))
    }

    func testInfoPlistSupportsLiveActivities() throws {
        let plist = try iosSource("TimeTap/Info.plist")
        XCTAssertTrue(plist.contains("<key>NSSupportsLiveActivities</key>"))
        XCTAssertTrue(
            plist.contains("<key>NSSupportsLiveActivities</key>\n\t<true/>"),
            "NSSupportsLiveActivities must be true"
        )
    }

    func testProjectYmlWiresWidgetAndSharedLiveActivitySources() throws {
        let yml = try iosSource("project.yml")
        XCTAssertTrue(yml.contains("iOS: \"17.2\""))
        let targets = slice(yml, from: "targets:", to: "schemes:")
        let app = slice(targets, from: "  TimeTap:\n", to: "  TimeTapWidget:")
        let widget = slice(targets, from: "  TimeTapWidget:", to: "  TimeTapTests:")
        XCTAssertTrue(app.contains("path: TimeTap"))
        XCTAssertFalse(app.contains("LiveActivity"), "app compiles LiveActivity via path: TimeTap")
        XCTAssertTrue(app.contains("INFOPLIST_FILE: TimeTap/Info.plist"))
        XCTAssertTrue(app.contains("target: TimeTapWidget"))
        XCTAssertTrue(app.contains("embed: true"))
        XCTAssertTrue(widget.contains("type: app-extension"))
        XCTAssertTrue(widget.contains("PRODUCT_BUNDLE_IDENTIFIER: app.timetap.ios.widget"))
        XCTAssertTrue(widget.contains("path: TimeTapWidget"))
        XCTAssertTrue(widget.contains("TimeTap/LiveActivity/RunningBlockAttributes.swift"))
        XCTAssertTrue(widget.contains("TimeTap/LiveActivity/RunningBlockIntents.swift"))
        XCTAssertTrue(widget.contains("TimeTap/Theme.swift"))
    }

    func testContentStateHasBlockAndTimerRanges() throws {
        XCTAssertFalse(RunningBlockAttributes.ContentState().hasBlock)
        XCTAssertFalse(RunningBlockAttributes.ContentState(key: "DW").hasBlock)
        XCTAssertFalse(RunningBlockAttributes.ContentState(startMs: 1_700_000_000_000).hasBlock)
        XCTAssertTrue(
            RunningBlockAttributes.ContentState(key: "DW", startMs: 1_700_000_000_000).hasBlock
        )
        let startMs: Double = 1_700_000_000_000
        let sitMs: Double = 1_700_000_010_000
        let standMs: Double = 1_700_000_060_000
        let block = RunningBlockAttributes.ContentState(
            key: "DW", startMs: startMs, sitting: true, sitStartMs: sitMs, standStartMs: standMs
        )
        let timer = try XCTUnwrap(block.timerRange)
        XCTAssertEqual(timer.lowerBound.timeIntervalSince1970, startMs / 1000)
        XCTAssertEqual(
            timer.upperBound.timeIntervalSince1970 - timer.lowerBound.timeIntervalSince1970,
            12 * 3600
        )
        XCTAssertEqual(
            try XCTUnwrap(block.postureTimerRange).lowerBound.timeIntervalSince1970,
            sitMs / 1000
        )
        XCTAssertEqual(block.postureTimerRange, block.sitTimerRange)
        let stand = RunningBlockAttributes.ContentState(
            key: "DW", startMs: startMs, sitting: false, sitStartMs: sitMs, standStartMs: standMs
        )
        XCTAssertNil(stand.sitTimerRange)
        XCTAssertEqual(
            try XCTUnwrap(stand.postureTimerRange).lowerBound.timeIntervalSince1970,
            standMs / 1000
        )
        let attrs = try iosSource("TimeTap/LiveActivity/RunningBlockAttributes.swift")
        XCTAssertTrue(attrs.contains("12 * 3600"))
    }

    func testEndDayLeavesSitRunningThenStopSitCloses() {
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
        XCTAssertTrue(store.queue.contains { $0.type == "closeActual" })
        XCTAssertFalse(store.queue.contains { $0.type == "closeSit" })
        store.stopSit()
        XCTAssertNil(store.sit)
        XCTAssertTrue(store.queue.contains { $0.type == "closeSit" })
        XCTAssertEqual(store.standStartMs, now)
    }

    private func iosSource(_ relative: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(relative),
            encoding: .utf8
        )
    }

    private func slice(_ text: String, from: String, to: String? = nil) -> String {
        let start = text.range(of: from)!.lowerBound
        let end = to.flatMap {
            text.range(of: $0, range: start..<text.endIndex)?.lowerBound
        } ?? text.endIndex
        return String(text[start..<end])
    }
}
