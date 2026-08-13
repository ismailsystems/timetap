import XCTest
@testable import TimeTap

@MainActor
final class LAIslandTests: TimeTapTestCase {
    func testCompactSlotsKeepBlockAndPostureApart() throws {
        let text = try liveActivity()
        let leading = slice(text, from: "compactLeading", to: "compactTrailing")
        let trailing = slice(text, from: "compactTrailing", to: "minimal")
        XCTAssertTrue(leading.contains("islandBlock"), "compact leading must be islandBlock only")
        XCTAssertFalse(leading.contains("islandPosture"), "compact leading must not also hold islandPosture")
        XCTAssertFalse(leading.contains("HStack"), "compact leading must not wrap block and posture in one HStack")
        XCTAssertTrue(trailing.contains("islandPosture"), "compact trailing must be islandPosture only")
        XCTAssertFalse(trailing.contains("islandBlock"), "compact trailing must not also hold islandBlock")
        XCTAssertTrue(leading.contains("timeWidth: 54"), "compact timeWidth must stay 54")
        XCTAssertTrue(trailing.contains("timeWidth: 54"), "compact trailing timeWidth must stay 54")
        XCTAssertFalse(text.contains("timeWidth: 62"), "compact timeWidth 62 overflows the island cap")
        XCTAssertTrue(leading.contains(".padding(.leading, 8)"), "compact leading inset from the island cap")
        XCTAssertTrue(trailing.contains(".padding(.trailing, 8)"), "compact trailing inset from the island cap")
    }

    func testExpandedIslandRegionsAndInsets() throws {
        let text = try liveActivity()
        XCTAssertTrue(
            text.contains("DynamicIslandExpandedRegion(.leading)"),
            "expanded leading region is gone"
        )
        XCTAssertTrue(
            text.contains("DynamicIslandExpandedRegion(.trailing)"),
            "expanded trailing region is gone"
        )
        XCTAssertTrue(
            text.contains("DynamicIslandExpandedRegion(.bottom)"),
            "expanded bottom region is gone"
        )
        XCTAssertTrue(text.contains("compactLeading"), "compact leading slot is gone")
        XCTAssertTrue(text.contains("compactTrailing"), "compact trailing slot is gone")
        XCTAssertTrue(text.contains("minimal"), "minimal island slot is gone")
        let leading = slice(
            text,
            from: "DynamicIslandExpandedRegion(.leading)",
            to: "DynamicIslandExpandedRegion(.trailing)"
        )
        let trailing = slice(
            text,
            from: "DynamicIslandExpandedRegion(.trailing)",
            to: "DynamicIslandExpandedRegion(.bottom)"
        )
        let bottom = slice(text, from: "DynamicIslandExpandedRegion(.bottom)", to: "compactLeading")
        XCTAssertTrue(leading.contains("islandBlock"), "expanded leading must be islandBlock")
        XCTAssertFalse(leading.contains("islandPosture"), "expanded leading must not hold islandPosture")
        XCTAssertTrue(trailing.contains("islandPosture"), "expanded trailing must be islandPosture")
        XCTAssertFalse(trailing.contains("islandBlock"), "expanded trailing must not hold islandBlock")
        XCTAssertTrue(leading.contains(".padding(.leading, 10)"), "expanded leading inset from the island cap")
        XCTAssertTrue(trailing.contains(".padding(.trailing, 10)"), "expanded trailing inset from the island cap")
        XCTAssertTrue(bottom.contains(".padding(.horizontal, 10)"), "expanded bottom inset from the island cap")
    }

    func testElapsedTimerIsClippedNotFlexible() throws {
        let elapsed = try read("TimeTap/LiveActivity/ElapsedTimer.swift")
        XCTAssertTrue(
            elapsed.contains("Text(timerInterval: range, countsDown: false, showsHours: true)"),
            "Island timers must count up and show hours"
        )
        XCTAssertTrue(
            elapsed.contains(".frame(width: width, height: size + 4, alignment: align)"),
            "Island timers must not claim a huge slot"
        )
        XCTAssertTrue(elapsed.contains(".clipped()"), "timerInterval overflows its frame unless clipped")
        XCTAssertLessThan(
            elapsed.range(of: ".frame(width: width, height: size + 4, alignment: align)")!.lowerBound,
            elapsed.range(of: ".clipped()")!.lowerBound,
            "timer must clip after the fixed frame"
        )
        XCTAssertFalse(elapsed.contains(".fixedSize()"), "timer must not use fixedSize")
        XCTAssertFalse(
            elapsed.contains(".frame(maxWidth: .infinity)"),
            "timer must not expand to infinity"
        )
        let la = try liveActivity()
        XCTAssertTrue(la.contains("ElapsedTimer("), "Live Activity must host ElapsedTimer")
        let wrapper = slice(la, from: "private func elapsed(", to: "private func categoryBar(")
        XCTAssertTrue(wrapper.contains("ElapsedTimer("), "elapsed() must wrap ElapsedTimer")
    }

    func testPostureNamesNotSittingWhenIdle() throws {
        let text = try liveActivity()
        let compact = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/LiveActivity/IslandCompact.swift"),
            encoding: .utf8
        )
        let posture = slice(text, from: "private func islandPosture(", to: "private func sittingRow(")
        let sitting = slice(text, from: "private func sittingRow(", to: "private func faceLabel(")
        XCTAssertTrue(
            posture.contains("state.sitting ? \"SITTING\" : \"NOT SITTING\""),
            "expanded right must name NOT SITTING when not sitting"
        )
        XCTAssertTrue(
            compact.contains("state.sitting ? \"SITTING\" : \"NOT SITTING\""),
            "compact right must name NOT SITTING when not sitting"
        )
        XCTAssertTrue(
            sitting.contains("state.sitting ? \"SITTING\" : \"NOT SITTING\""),
            "lock screen sitting row must name NOT SITTING when not sitting"
        )
        XCTAssertFalse(text.contains("STANDING"), "Live Activity must not say STANDING")
        XCTAssertFalse(compact.contains("STANDING"), "compact Island must not say STANDING")
    }

    func testLockScreenShowsCategoryBarStopAndAlwaysSittingRow() throws {
        let text = try liveActivity()
        let lock = slice(text, from: "private func lockScreen(", to: "private var blockStop")
        let stop = slice(text, from: "private var blockStop", to: "private func islandBlock(")
        XCTAssertTrue(lock.contains("if state.hasBlock"), "category bar and STOP must gate on a running block")
        XCTAssertTrue(lock.contains("categoryBar"), "lock screen must show the category bar when a block is running")
        XCTAssertTrue(lock.contains("blockStop"), "lock screen must show STOP when a block is running")
        XCTAssertTrue(stop.contains("StopBlockIntent"), "lock screen STOP must use StopBlockIntent")
        XCTAssertTrue(
            lock.contains("sittingRow(state, compact: false)"),
            "lock screen must always show sittingRow"
        )
        XCTAssertTrue(
            lock.contains("}\n            sittingRow(state, compact: false)"),
            "sittingRow must sit outside hasBlock so standing-only still shows posture"
        )
    }

    func testSitButtonsLiveInSittingRowNotCompactSlots() throws {
        let text = try liveActivity()
        let sitting = slice(text, from: "private func sittingRow(", to: "private func faceLabel(")
        let leading = slice(text, from: "compactLeading", to: "compactTrailing")
        let trailing = slice(text, from: "compactTrailing", to: "minimal")
        let bottom = slice(text, from: "DynamicIslandExpandedRegion(.bottom)", to: "compactLeading")
        XCTAssertTrue(sitting.contains("if state.sitting"), "sittingRow START and STOP must follow sitting")
        XCTAssertTrue(sitting.contains("StopSitIntent"), "sittingRow STOP must use StopSitIntent")
        XCTAssertTrue(sitting.contains("ToggleSitIntent"), "sittingRow START must use ToggleSitIntent")
        XCTAssertTrue(sitting.contains("Text(\"STOP\")"), "sittingRow names STOP when sitting")
        XCTAssertTrue(sitting.contains("Text(\"START\")"), "sittingRow names START when not sitting")
        XCTAssertTrue(bottom.contains("sittingRow"), "sit buttons must live in expanded bottom")
        XCTAssertTrue(bottom.contains("blockStop"), "block STOP must live in expanded bottom")
        XCTAssertFalse(leading.contains("Button"), "sit buttons must not live in compactLeading")
        XCTAssertFalse(trailing.contains("Button"), "sit buttons must not live in compactTrailing")
        XCTAssertFalse(leading.contains("sittingRow"), "sittingRow must not live in compactLeading")
        XCTAssertFalse(trailing.contains("sittingRow"), "sittingRow must not live in compactTrailing")
        XCTAssertFalse(leading.contains("ToggleSitIntent"), "START must not live in compactLeading")
        XCTAssertFalse(trailing.contains("ToggleSitIntent"), "START must not live in compactTrailing")
        XCTAssertFalse(leading.contains("StopSitIntent"), "sit STOP must not live in compactLeading")
        XCTAssertFalse(trailing.contains("StopSitIntent"), "sit STOP must not live in compactTrailing")
    }

    func testIslandChromeIsPostureSymbolNotDotStripOrRing() throws {
        let text = try liveActivity()
        let theme = try read("TimeTap/Theme.swift")
        XCTAssertTrue(text.contains("Theme.postureSymbol"), "sit/stand icon must be Theme.postureSymbol")
        XCTAssertTrue(
            text.contains("Image(systemName: Theme.postureSymbol(sitting: sitting))"),
            "posture icon must use Theme.postureSymbol"
        )
        XCTAssertFalse(text.contains("sitDot"), "red sit dot must be a figure icon")
        XCTAssertFalse(
            text.contains("frame(width: 4)"),
            "Live Activity must not add a red strip beside the category bar"
        )
        XCTAssertFalse(text.contains("keylineTint"), "Island keyline is a second red edge")
        XCTAssertFalse(text.contains("progressViewStyle"), "Live Activity must not become a timer ring")
        XCTAssertTrue(theme.contains("figure.stand"), "stand icon must stay figure.stand")
        XCTAssertTrue(
            theme.contains("figure.seated.side.right"),
            "sit icon must stay figure.seated.side.right"
        )
        XCTAssertTrue(
            theme.contains("sitting ? \"figure.seated.side.right\" : \"figure.stand\""),
            "Theme.postureSymbol must map sit and stand to those figures"
        )
    }

    func testEmptyCompactLeadingIsOneClearPoint() throws {
        let block = slice(
            try liveActivity(),
            from: "private func islandBlock(",
            to: "private func islandPosture("
        )
        XCTAssertTrue(
            block.contains("Color.clear.frame(width: 1, height: 1)"),
            "empty compact leading must be a 1pt clear point"
        )
        guard let emptyAt = block.range(of: "} else {") else {
            return XCTFail("islandBlock must have an empty leading branch")
        }
        let empty = block[emptyAt.lowerBound...]
        XCTAssertTrue(
            empty.contains("Color.clear.frame(width: 1, height: 1)"),
            "empty compact leading must be a 1pt clear point"
        )
        XCTAssertFalse(empty.contains("VStack"), "empty compact leading must not be a two-line VStack")
    }

    func testWidgetBundleIsOnlyTheLiveActivity() throws {
        let bundle = try read("TimeTapWidget/TimeTapWidgetBundle.swift")
        XCTAssertTrue(
            bundle.contains("RunningBlockLiveActivity()"),
            "widget bundle must host the Live Activity"
        )
        guard let open = bundle.range(of: "var body: some Widget {") else {
            return XCTFail("widget bundle body is gone")
        }
        guard let close = bundle.range(of: "}", range: open.upperBound..<bundle.endIndex) else {
            return XCTFail("widget bundle body has no close")
        }
        let inner = bundle[open.upperBound..<close.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(inner, "RunningBlockLiveActivity()", "widget bundle body is only the Live Activity")
        let plist = try read("TimeTapWidget/Info.plist")
        XCTAssertTrue(
            plist.contains("NSExtensionPointIdentifier"),
            "widget Info.plist must declare the extension point"
        )
        XCTAssertTrue(
            plist.contains("com.apple.widgetkit-extension"),
            "widget extension point must stay widgetkit"
        )
        XCTAssertTrue(
            plist.contains(
                "<key>NSExtensionPointIdentifier</key>\n\t\t<string>com.apple.widgetkit-extension</string>"
            ),
            "NSExtensionPointIdentifier must be com.apple.widgetkit-extension"
        )
    }

    private func liveActivity() throws -> String {
        try read("TimeTapWidget/RunningBlockLiveActivity.swift")
    }

    private func read(_ relative: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(relative),
            encoding: .utf8
        )
    }

    private func slice(_ text: String, from: String, to: String) -> Substring {
        guard let a = text.range(of: from), let b = text.range(of: to), a.lowerBound < b.lowerBound else {
            XCTFail("source lost \(from) .. \(to)")
            return ""
        }
        return text[a.lowerBound..<b.lowerBound]
    }
}
