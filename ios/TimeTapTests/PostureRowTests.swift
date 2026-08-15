import XCTest
@testable import TimeTap

@MainActor
final class PostureRowTests: TimeTapTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
    }

    // MARK: - Sit-body source pins (sitChip .. markLabel)

    func testIdleLabelIsStandingNeverTapToSit() throws {
        let text = try captureText()
        let body = try sitChipBody(in: text)
        XCTAssertTrue(
            body.contains("\"NOT SITTING\""),
            "idle sit chip must say NOT SITTING"
        )
        XCTAssertTrue(
            body.contains("sitting ? \"SITTING\" : \"NOT SITTING\""),
            "idle (not sitting) label is NOT SITTING"
        )
        XCTAssertFalse(body.contains("STANDING"), "sit chip must not say STANDING")
        XCTAssertFalse(
            text.contains("TAP TO SIT"),
            "idle sit must never say TAP TO SIT"
        )
    }

    func testSittingLabelIsSitting() throws {
        let body = try sitChipBody()
        XCTAssertTrue(
            body.contains("\"SITTING\""),
            "sitting chip must say SITTING"
        )
        XCTAssertTrue(
            body.contains("sitting ? \"SITTING\" : \"NOT SITTING\""),
            "sitting label is SITTING"
        )
    }

    func testPostureElapsedAlwaysShowsSitOrStandStart() throws {
        let text = try captureText()
        let elapsedStart = try XCTUnwrap(
            text.range(of: "private var postureElapsed"),
            "postureElapsed helper is missing"
        )
        let sitStart = try XCTUnwrap(
            text.range(of: "private var sitChip"),
            "sitChip is missing"
        )
        XCTAssertLessThan(
            elapsedStart.lowerBound,
            sitStart.lowerBound,
            "postureElapsed must sit next to sitChip"
        )
        let elapsed = text[elapsedStart.lowerBound..<sitStart.lowerBound]
        XCTAssertTrue(
            elapsed.contains("store.sit?.startMs ?? store.standStartMs"),
            "duration must use sit?.startMs ?? standStartMs"
        )
        XCTAssertFalse(
            elapsed.contains("if sitting"),
            "postureElapsed must not gate on if sitting"
        )
        XCTAssertFalse(
            elapsed.contains("sitting ?"),
            "postureElapsed must not gate duration on sitting"
        )
        let body = try sitChipBody(in: text)
        XCTAssertTrue(
            body.contains("Text(postureElapsed)"),
            "standing still shows a duration via postureElapsed"
        )
        XCTAssertFalse(
            body.contains("if sitting { Text(postureElapsed)"),
            "duration must not hide when standing"
        )
    }

    func testSitChipAlwaysUsesPanelBackgroundNotClear() throws {
        let body = try sitChipBody()
        XCTAssertTrue(
            body.contains(".background(Theme.panel)"),
            "posture row always uses Theme.panel"
        )
        XCTAssertFalse(
            body.contains("sitting ? Theme.panel"),
            "panel fill must not be sitting ? Theme.panel : Color.clear"
        )
        XCTAssertFalse(
            body.contains("Color.clear"),
            "idle posture must not use Color.clear"
        )
    }

    func testSitChipIconAndTitleUseFgNotMute() throws {
        let body = String(try sitChipBody())
        let fgCount = body.components(separatedBy: ".foregroundStyle(Theme.fg)").count - 1
        XCTAssertGreaterThanOrEqual(
            fgCount,
            2,
            "icon and title must use Theme.fg"
        )
        XCTAssertFalse(
            body.contains("Theme.mute"),
            "idle posture icon and title must not use Theme.mute"
        )
    }

    func testSitChipAlwaysAddsIsSelectedTrait() throws {
        let body = try sitChipBody()
        XCTAssertTrue(
            body.contains(".accessibilityAddTraits(.isSelected)"),
            "VoiceOver must always treat the posture row as selected"
        )
        XCTAssertFalse(
            body.contains("sitting ? [.isSelected]"),
            ".isSelected must not gate on sitting"
        )
        XCTAssertFalse(
            body.contains("[.isSelected] : []"),
            ".isSelected must not drop when standing"
        )
    }

    func testSitChipUsesThemePostureSymbol() throws {
        let body = try sitChipBody()
        XCTAssertTrue(
            body.contains("Theme.postureSymbol(sitting:"),
            "sit chip icon must be Theme.postureSymbol(sitting:)"
        )
        XCTAssertTrue(
            body.contains("Image(systemName: Theme.postureSymbol(sitting: sitting))"),
            "icon must pass sitting into Theme.postureSymbol"
        )
    }

    func testSitChipIsOneToggleButtonWithAdjustStartOnlyWhenSitting() throws {
        let text = try captureText()
        let body = try sitChipBody(in: text)
        XCTAssertTrue(
            body.contains("store.toggleSit()"),
            "the row must be one button that toggleSit()"
        )
        XCTAssertFalse(
            text.contains("Button(action: store.openSitEdit)"),
            "sitting chip must not be a STOP chip plus a separate clock"
        )
        XCTAssertFalse(
            body.contains("outlineChip"),
            "sit chip must not be a STOP outline chip"
        )
        XCTAssertTrue(
            body.contains(".contextMenu"),
            "long-press must offer Adjust sitting start"
        )
        XCTAssertTrue(
            body.contains("Adjust sitting start"),
            "long-press/context menu must name Adjust sitting start"
        )
        let menuStart = try XCTUnwrap(
            body.range(of: ".contextMenu"),
            "context menu is missing"
        )
        let menu = body[menuStart.lowerBound...]
        XCTAssertTrue(
            menu.contains("if sitting"),
            "Adjust sitting start must show only when sitting"
        )
        XCTAssertTrue(
            menu.contains("store.openSitEdit()"),
            "Adjust sitting start must open sit edit"
        )
    }

    func testSitChipIsListRowWithoutStrokeBorder() throws {
        let body = try sitChipBody()
        XCTAssertFalse(
            body.contains("strokeBorder"),
            "sitChip is a list row; sitBody must not strokeBorder"
        )
    }

    // MARK: - Placement

    func testSitChipSitsAfterCategoriesNotInFooter() throws {
        let text = try captureText()
        XCTAssertFalse(text.contains("private var addRow"), "add row left the capture grid")
        XCTAssertFalse(text.contains("Text(\"+\")"), "add lives in Settings")
        let forEach = try XCTUnwrap(
            text.range(of: "ForEach(store.groups)"),
            "group ForEach is missing"
        )
        let sit = try XCTUnwrap(
            text.range(of: "sitChip"),
            "sitChip usage is missing"
        )
        XCTAssertLessThan(
            forEach.lowerBound,
            sit.lowerBound,
            "sitChip must sit after ForEach(store.groups)"
        )
        XCTAssertFalse(text.contains("settingsRow"), "gear left the category column")
        let list = try XCTUnwrap(
            text.range(of: "private func categoryList"),
            "categoryList is missing"
        )
        let footerAt = try XCTUnwrap(
            text.range(of: "private var footer"),
            "footer is missing"
        )
        let column = text[list.lowerBound..<footerAt.lowerBound]
        XCTAssertTrue(
            column.contains("groups.count + 1"),
            "groups and sit share one row height"
        )
        XCTAssertTrue(
            column.contains("height - rowH"),
            "list rows fill the space above NOT SITTING"
        )
        XCTAssertTrue(
            column.contains("minHeight: rowH, maxHeight: rowH"),
            "NOT SITTING uses the same row height as the category buttons"
        )
        XCTAssertFalse(
            column.contains("nowH"),
            "the gear row left the category column"
        )
        XCTAssertLessThan(
            column.range(of: "height - rowH")!.lowerBound,
            column.range(of: "sitChip")!.lowerBound,
            "sit sits under the category scroll so Poop cannot leave a gap"
        )
        let footerStart = try XCTUnwrap(
            text.range(of: "private var footer"),
            "footer is missing"
        )
        let footerEnd = try XCTUnwrap(
            text.range(of: "private var elapsedLabel"),
            "elapsedLabel is missing"
        )
        XCTAssertLessThan(footerStart.lowerBound, footerEnd.lowerBound)
        let footer = text[footerStart.lowerBound..<footerEnd.lowerBound]
        XCTAssertFalse(
            footer.contains("sitChip"),
            "footer must not contain sitChip"
        )
        XCTAssertLessThan(
            sit.lowerBound,
            footerStart.lowerBound,
            "sitChip usage must sit in the category list, not the footer"
        )
    }

    func testCaptureViewDoesNotMentionLiveActivity() throws {
        let text = try captureText()
        XCTAssertFalse(
            text.contains("ActivityKit"),
            "CaptureView must not import or mention ActivityKit; LA stays off the canvas"
        )
        XCTAssertFalse(
            text.contains("LiveActivity"),
            "CaptureView must not import or mention LiveActivity; LA stays off the canvas"
        )
    }

    // MARK: - Theme

    func testThemePostureSymbolMapsSitAndStand() throws {
        XCTAssertEqual(
            Theme.postureSymbol(sitting: true),
            "figure.seated.side.right",
            "sitting maps to figure.seated.side.right"
        )
        XCTAssertEqual(
            Theme.postureSymbol(sitting: false),
            "figure.stand",
            "standing maps to figure.stand"
        )
        let theme = try String(
            contentsOf: iosRoot().appendingPathComponent("TimeTap/Theme.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            theme.contains("static func postureSymbol(sitting: Bool)"),
            "Theme must map posture through postureSymbol(sitting:)"
        )
        XCTAssertTrue(
            theme.contains("figure.seated.side.right"),
            "Theme sitting symbol must be figure.seated.side.right"
        )
        XCTAssertTrue(
            theme.contains("figure.stand"),
            "Theme standing symbol must be figure.stand"
        )
    }

    // MARK: - TapStore behaviour

    func testToggleSitOpensThenClearsSitAndSetsStandStart() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        XCTAssertTrue(store.sessionReady, "sessionReady is true after TapStore.init")
        store.sit = nil
        store.toggleSit()
        XCTAssertNotNil(store.sit, "toggleSit when sit is nil must open sit")
        XCTAssertEqual(store.sit?.startMs, now)
        XCTAssertTrue(store.queue.contains { $0.type == "openSit" })
        now += 1_000
        store.toggleSit()
        XCTAssertNil(store.sit, "toggleSit again must clear sit")
        XCTAssertEqual(store.standStartMs, now, "toggleSit again must set standStartMs")
        XCTAssertTrue(store.queue.contains { $0.type == "closeSit" })
        now += 1_000
        store.toggleSit()
        XCTAssertNotNil(store.sit, "toggleSit after standing must open sit again")
        now += 1_000
        store.stopSit()
        XCTAssertNil(store.sit, "stopSit must clear sit")
        XCTAssertEqual(store.standStartMs, now, "stopSit must set standStartMs")
    }

    func testEndDayLeavesSittingRunningWithoutCloseSit() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        XCTAssertTrue(store.sessionReady, "sessionReady is true after TapStore.init")
        store.tapCategory("Deep work")
        now += 1_000
        store.toggleSit()
        now += 60_000
        store.endDay()
        XCTAssertNil(store.open)
        XCTAssertNotNil(store.sit, "endDay with sit running must leave sit non-nil")
        XCTAssertFalse(
            store.queue.contains { $0.type == "closeSit" },
            "endDay must not enqueue closeSit"
        )
    }

    // MARK: - Source helpers

    private func iosRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func captureText() throws -> String {
        try String(
            contentsOf: iosRoot().appendingPathComponent("TimeTap/Views/CaptureView.swift"),
            encoding: .utf8
        )
    }

    private func sitChipBody(in text: String? = nil) throws -> Substring {
        let text = try text ?? captureText()
        let start = try XCTUnwrap(
            text.range(of: "private var sitChip"),
            "private var sitChip is missing"
        )
        let end = try XCTUnwrap(
            text.range(of: "private func markLabel"),
            "markLabel is missing; sit-body slice ends there"
        )
        XCTAssertLessThan(
            start.lowerBound,
            end.lowerBound,
            "sitChip must sit before markLabel"
        )
        return text[start.lowerBound..<end.lowerBound]
    }
}
