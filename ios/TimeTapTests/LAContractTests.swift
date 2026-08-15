import XCTest
import notify
@testable import TimeTap
import notify

private final class DarwinHits: @unchecked Sendable {
    var toggle = 0
    var stopSit = 0
    var endDay = 0
}

private let darwinHits = DarwinHits()
private var darwinNotifyTokens: [Int32] = []

@MainActor
final class LAContractTests: TimeTapTestCase {

    override func setUp() {
        super.setUp()
        LiveActivityDarwin.onToggleSit = {}
        LiveActivityDarwin.onStopSit = {}
        LiveActivityDarwin.onEndDay = {}
    }

    override func tearDown() {
        darwinNotifyTokens.forEach { notify_cancel($0) }
        darwinNotifyTokens = []
        darwinHits.toggle = 0
        darwinHits.stopSit = 0
        darwinHits.endDay = 0
        LiveActivityDarwin.onToggleSit = {}
        LiveActivityDarwin.onStopSit = {}
        LiveActivityDarwin.onEndDay = {}
        super.tearDown()
    }

    func testIntentsAreUndiscoverableBackgroundLiveActivityIntents() throws {
        let text = try iosSource("TimeTap/LiveActivity/RunningBlockIntents.swift")
        XCTAssertFalse(text.contains("= {}"), "empty LiveActivityActions defaults are gone")
        XCTAssertFalse(text.contains("enum LiveActivityActions"), "intents post Darwin, not empty closures")
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
            XCTAssertTrue(body.contains("LiveActivityDarwin.post"))
            XCTAssertFalse(body.contains("openAppWhenRun = true"))
        }
        XCTAssertTrue(toggle.contains("LiveActivityDarwin.toggleSit"))
        XCTAssertTrue(stopSit.contains("LiveActivityDarwin.stopSit"))
        XCTAssertTrue(stopBlock.contains("LiveActivityDarwin.endDay"))
        XCTAssertTrue(text.contains("app.timetap.ios.toggleSit"))
        XCTAssertTrue(text.contains("app.timetap.ios.stopSit"))
        XCTAssertTrue(text.contains("app.timetap.ios.endDay"))
        XCTAssertTrue(text.contains("CFNotificationCenterGetDarwinNotifyCenter"))
        XCTAssertFalse(stopBlock.contains("closeSit"))
        XCTAssertFalse(stopBlock.contains("stopSit"))
        XCTAssertFalse(ToggleSitIntent.openAppWhenRun)
        XCTAssertFalse(StopSitIntent.openAppWhenRun)
        XCTAssertFalse(StopBlockIntent.openAppWhenRun)
        XCTAssertFalse(ToggleSitIntent.isDiscoverable)
        XCTAssertFalse(StopSitIntent.isDiscoverable)
        XCTAssertFalse(StopBlockIntent.isDiscoverable)
    }

    func testIntentPerformPostsDarwin() async throws {
        installDarwinHits()
        _ = try await ToggleSitIntent().perform()
        await waitHits({ darwinHits.toggle >= 1 })
        XCTAssertGreaterThanOrEqual(darwinHits.toggle, 1)
        XCTAssertEqual(darwinHits.stopSit, 0)
        XCTAssertEqual(darwinHits.endDay, 0)
        _ = try await StopSitIntent().perform()
        await waitHits({ darwinHits.stopSit >= 1 })
        XCTAssertGreaterThanOrEqual(darwinHits.toggle, 1)
        XCTAssertGreaterThanOrEqual(darwinHits.stopSit, 1)
        XCTAssertEqual(darwinHits.endDay, 0)
        _ = try await StopBlockIntent().perform()
        await waitHits({ darwinHits.endDay >= 1 })
        XCTAssertGreaterThanOrEqual(darwinHits.toggle, 1)
        XCTAssertGreaterThanOrEqual(darwinHits.stopSit, 1)
        XCTAssertGreaterThanOrEqual(darwinHits.endDay, 1)
    }

    func testAppInitWiresLiveActivityActions() throws {
        let text = try iosSource("TimeTap/TimeTapApp.swift")
        XCTAssertTrue(text.contains("LiveActivityDarwin.observe"))
        XCTAssertTrue(text.contains("store.handleSitIntent()"))
        XCTAssertTrue(text.contains("store.handleStopSitIntent()"))
        XCTAssertTrue(text.contains("store.handleStopIntent()"))
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
        XCTAssertTrue(widget.contains("TimeTap/LiveActivity/ElapsedTimer.swift"))
        XCTAssertTrue(widget.contains("TimeTap/Theme.swift"))
        XCTAssertTrue(yml.contains("TimeTapUITests"))
        XCTAssertTrue(yml.contains("PRODUCT_BUNDLE_IDENTIFIER: app.timetap.ios.uitests"))
        XCTAssertTrue(yml.contains("- TimeTapUITests"))
    }

    func testContentStateHasBlockAndTimerRanges() throws {
        XCTAssertFalse(RunningBlockAttributes.ContentState().hasBlock)
        XCTAssertFalse(RunningBlockAttributes.ContentState(key: "Deep work").hasBlock)
        XCTAssertFalse(RunningBlockAttributes.ContentState(startMs: 1_700_000_000_000).hasBlock)
        XCTAssertTrue(
            RunningBlockAttributes.ContentState(key: "Deep work", startMs: 1_700_000_000_000).hasBlock
        )
        let startMs: Double = 1_700_000_000_000
        let sitMs: Double = 1_700_000_010_000
        let standMs: Double = 1_700_000_060_000
        let block = RunningBlockAttributes.ContentState(
            key: "Deep work", startMs: startMs, sitting: true, sitStartMs: sitMs, standStartMs: standMs
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
            key: "Deep work", startMs: startMs, sitting: false, sitStartMs: sitMs, standStartMs: standMs
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
        store.tapCategory("Deep work")
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

    private func installDarwinHits() {
        darwinHits.toggle = 0
        darwinHits.stopSit = 0
        darwinHits.endDay = 0
        darwinNotifyTokens.forEach { notify_cancel($0) }
        darwinNotifyTokens = []
        for name in [LiveActivityDarwin.toggleSit, LiveActivityDarwin.stopSit, LiveActivityDarwin.endDay] {
            var token: Int32 = 0
            notify_register_dispatch(name, &token, .main) { _ in
                switch name {
                case LiveActivityDarwin.toggleSit: darwinHits.toggle += 1
                case LiveActivityDarwin.stopSit: darwinHits.stopSit += 1
                case LiveActivityDarwin.endDay: darwinHits.endDay += 1
                default: break
                }
            }
            darwinNotifyTokens.append(token)
        }
    }

    private func waitHits(_ ready: () -> Bool) async {
        for _ in 0..<40 {
            if ready() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
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
