import XCTest
@testable import TimeTap

/// Live Activity Lock Screen / Island buttons run in TimeTapWidget.appex.
/// Darwin observer tests in this bundle run in the app test host.
///
/// These pins prove the extension compiles the intents, does not register
/// Darwin handlers, and only posts; the app process is the observer.
/// They do not execute TimeTapWidget.appex. This unit-test bundle cannot
/// spawn a real widget extension process. Do not treat an in-host
/// `perform()` + Darwin hit as proof that the appex posted.
@MainActor
final class IslandWidgetProcessTests: TimeTapTestCase {

    func testWidgetTargetCompilesRunningBlockIntents() throws {
        let widget = slice(try read("project.yml"), from: "  TimeTapWidget:", to: "  TimeTapTests:")
        XCTAssertTrue(widget.contains("type: app-extension"), "TimeTapWidget must stay an app-extension")
        XCTAssertTrue(
            widget.contains("- path: TimeTap/LiveActivity/RunningBlockIntents.swift"),
            "TimeTapWidget sources must compile RunningBlockIntents.swift"
        )
    }

    func testWidgetInfoPlistIsWidgetKitExtension() throws {
        let plist = try read("TimeTapWidget/Info.plist")
        XCTAssertTrue(
            plist.contains(
                "<key>NSExtensionPointIdentifier</key>\n\t\t<string>com.apple.widgetkit-extension</string>"
            ),
            "NSExtensionPointIdentifier must be com.apple.widgetkit-extension"
        )
    }

    func testAppInfoPlistSupportsLiveActivities() throws {
        let plist = try read("TimeTap/Info.plist")
        XCTAssertTrue(
            plist.contains("<key>NSSupportsLiveActivities</key>\n\t<true/>"),
            "NSSupportsLiveActivities must be true"
        )
    }

    func testWidgetBundleBodyIsOnlyRunningBlockLiveActivity() throws {
        let bundle = try read("TimeTapWidget/TimeTapWidgetBundle.swift")
        guard let open = bundle.range(of: "var body: some Widget {") else {
            return XCTFail("widget bundle body is gone")
        }
        guard let close = bundle.range(of: "}", range: open.upperBound..<bundle.endIndex) else {
            return XCTFail("widget bundle body has no close")
        }
        let inner = bundle[open.upperBound..<close.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(inner, "RunningBlockLiveActivity()", "widget bundle body is only the Live Activity")
    }

    func testWidgetSwiftSourcesDoNotObserveDarwin() throws {
        let dir = iosRoot().appendingPathComponent("TimeTapWidget")
        let files = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty, "TimeTapWidget Swift sources are gone")
        let names = Set(files.map(\.lastPathComponent))
        XCTAssertTrue(names.contains("TimeTapWidgetBundle.swift"), "widget bundle source is gone")
        XCTAssertTrue(names.contains("RunningBlockLiveActivity.swift"), "Live Activity source is gone")
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(
                text.contains("LiveActivityDarwin.observe"),
                "\(url.lastPathComponent) must not register Darwin handlers; the app process observes"
            )
        }
    }

    func testIntentPerformPostsDarwinOnly() throws {
        let intents = try read("TimeTap/LiveActivity/RunningBlockIntents.swift")
        XCTAssertFalse(intents.contains("TapStore"), "intents must not touch TapStore")
        XCTAssertFalse(intents.contains("= {}"), "empty LiveActivityActions defaults are gone")
        let toggle = slice(intents, from: "struct ToggleSitIntent", to: "struct StopSitIntent")
        let stopSit = slice(intents, from: "struct StopSitIntent", to: "struct StopBlockIntent")
        let stopBlock = slice(intents, from: "struct StopBlockIntent")
        let performs: [(name: String, body: String, post: String)] = [
            ("ToggleSitIntent", toggle, "LiveActivityDarwin.post(LiveActivityDarwin.toggleSit)"),
            ("StopSitIntent", stopSit, "LiveActivityDarwin.post(LiveActivityDarwin.stopSit)"),
            ("StopBlockIntent", stopBlock, "LiveActivityDarwin.post(LiveActivityDarwin.endDay)"),
        ]
        for item in performs {
            let perform = slice(item.body, from: "func perform()")
            XCTAssertTrue(perform.contains(item.post), "\(item.name).perform must post Darwin")
            XCTAssertTrue(perform.contains("return .result()"), "\(item.name).perform must return")
            XCTAssertFalse(
                perform.contains("observe"),
                "\(item.name).perform must not register Darwin handlers"
            )
            XCTAssertFalse(perform.contains("TapStore"), "\(item.name).perform must not touch TapStore")
            XCTAssertFalse(perform.contains("= {}"), "\(item.name).perform must not use empty closures")
        }
    }

    func testAppInitObservesDarwin() throws {
        let app = try read("TimeTap/TimeTapApp.swift")
        let initBody = slice(app, from: "init() {", to: "var body:")
        XCTAssertTrue(
            initBody.contains("LiveActivityDarwin.observe("),
            "the app process must register Darwin handlers in TimeTapApp.init"
        )
        XCTAssertTrue(initBody.contains("store.handleSitIntent()"), "toggleSit observer is the app store")
        XCTAssertTrue(initBody.contains("store.handleStopSitIntent()"), "stopSit observer is the app store")
        XCTAssertTrue(initBody.contains("store.handleStopIntent()"), "endDay observer is the app store")
    }

    func testCompactIslandSlotsHaveNoIntentButtons() throws {
        let la = try read("TimeTapWidget/RunningBlockLiveActivity.swift")
        let compact = slice(la, from: "compactLeading", to: "minimal")
        let sitting = slice(la, from: "private func sittingRow(", to: "private func faceLabel(")
        let stop = slice(la, from: "private var blockStop", to: "private func islandBlock(")
        let lock = slice(la, from: "private func lockScreen(", to: "private var blockStop")
        let bottom = slice(la, from: "DynamicIslandExpandedRegion(.bottom)", to: "compactLeading")
        XCTAssertFalse(compact.contains("Button(intent:"), "compactLeading..minimal must not host Lock Screen buttons")
        XCTAssertFalse(compact.contains("sittingRow"), "sittingRow must not live in compactLeading..minimal")
        XCTAssertFalse(compact.contains("blockStop"), "blockStop must not live in compactLeading..minimal")
        XCTAssertFalse(compact.contains("StopBlockIntent"), "STOP must not live in compactLeading/compactTrailing")
        XCTAssertFalse(compact.contains("StopSitIntent"), "sit STOP must not live in compactLeading/compactTrailing")
        XCTAssertFalse(compact.contains("ToggleSitIntent"), "START must not live in compactLeading/compactTrailing")
        XCTAssertTrue(sitting.contains("Button(intent: StopSitIntent())"), "sittingRow STOP lives here")
        XCTAssertTrue(sitting.contains("Button(intent: ToggleSitIntent())"), "sittingRow START lives here")
        XCTAssertTrue(stop.contains("Button(intent: StopBlockIntent())"), "block STOP lives in blockStop")
        XCTAssertTrue(lock.contains("blockStop"), "lock screen hosts blockStop")
        XCTAssertTrue(lock.contains("sittingRow"), "lock screen hosts sittingRow")
        XCTAssertTrue(bottom.contains("blockStop"), "expanded bottom hosts blockStop")
        XCTAssertTrue(bottom.contains("sittingRow"), "expanded bottom hosts sittingRow")
    }

    func testIslandButtonsAreBackgroundLiveActivityIntents() throws {
        let la = try read("TimeTapWidget/RunningBlockLiveActivity.swift")
        XCTAssertEqual(
            la.components(separatedBy: "Button(intent:").count - 1,
            3,
            "Live Activity must have exactly three intent buttons"
        )
        XCTAssertTrue(la.contains("Button(intent: StopBlockIntent())"), "block STOP must use StopBlockIntent")
        XCTAssertTrue(la.contains("Button(intent: StopSitIntent())"), "sit STOP must use StopSitIntent")
        XCTAssertTrue(la.contains("Button(intent: ToggleSitIntent())"), "START must use ToggleSitIntent")
        let intents = try read("TimeTap/LiveActivity/RunningBlockIntents.swift")
        for name in ["ToggleSitIntent", "StopSitIntent", "StopBlockIntent"] {
            XCTAssertTrue(intents.contains("struct \(name): LiveActivityIntent"), "\(name) must be LiveActivityIntent")
        }
        XCTAssertFalse(ToggleSitIntent.openAppWhenRun)
        XCTAssertFalse(StopSitIntent.openAppWhenRun)
        XCTAssertFalse(StopBlockIntent.openAppWhenRun)
        let toggle = slice(intents, from: "struct ToggleSitIntent", to: "struct StopSitIntent")
        let stopSit = slice(intents, from: "struct StopSitIntent", to: "struct StopBlockIntent")
        let stopBlock = slice(intents, from: "struct StopBlockIntent")
        for body in [toggle, stopSit, stopBlock] {
            XCTAssertTrue(
                body.contains("openAppWhenRun = false")
                    || body.contains("openAppWhenRun: Bool = false"),
                "Island buttons must not open the app"
            )
        }
    }

    func testDarwinNotificationNamesStayStable() throws {
        XCTAssertEqual(LiveActivityDarwin.toggleSit, "app.timetap.ios.toggleSit")
        XCTAssertEqual(LiveActivityDarwin.stopSit, "app.timetap.ios.stopSit")
        XCTAssertEqual(LiveActivityDarwin.endDay, "app.timetap.ios.endDay")
        let intents = try read("TimeTap/LiveActivity/RunningBlockIntents.swift")
        XCTAssertTrue(intents.contains("app.timetap.ios.toggleSit"))
        XCTAssertTrue(intents.contains("app.timetap.ios.stopSit"))
        XCTAssertTrue(intents.contains("app.timetap.ios.endDay"))
    }

    private func iosRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func read(_ relative: String) throws -> String {
        try String(contentsOf: iosRoot().appendingPathComponent(relative), encoding: .utf8)
    }

    private func slice(_ text: String, from: String, to: String? = nil) -> String {
        guard let a = text.range(of: from) else {
            XCTFail("source lost \(from)")
            return ""
        }
        let end: String.Index
        if let to, let b = text.range(of: to, range: a.lowerBound..<text.endIndex), a.lowerBound < b.lowerBound {
            end = b.lowerBound
        } else if to == nil {
            end = text.endIndex
        } else {
            XCTFail("source lost \(from) .. \(to!)")
            return ""
        }
        return String(text[a.lowerBound..<end])
    }
}
