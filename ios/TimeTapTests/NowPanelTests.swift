import XCTest
@testable import TimeTap

@MainActor
final class NowPanelTests: TimeTapTestCase {
    func testTitleBarIsTimeTapAndSettingsGear() throws {
        let text = try captureView()
        let titleBar = try slice(text, from: "private var titleBar", to: "private var noteField")
        XCTAssertTrue(titleBar.contains("Text(\"TimeTap\")"), "title is TimeTap")
        XCTAssertTrue(titleBar.contains("Theme.rowFont(22, weight: .bold)"), "title is 10% larger and bold")
        XCTAssertTrue(titleBar.contains("alignment: .leading"), "title is left justified")
        XCTAssertTrue(titleBar.contains("gearshape"), "gear sits on the title row")
        XCTAssertTrue(titleBar.contains("store.showSettings = true"), "gear opens settings")
        XCTAssertFalse(titleBar.contains("NOTHING RUNNING"), "running title left the title row")
        XCTAssertFalse(titleBar.contains("elapsedLabel"), "elapsed left the title row")
        XCTAssertFalse(text.contains("settingsRow"), "gear left the capture chrome")
        XCTAssertFalse(text.contains("nowRowHeight"), "NOW row left the rails")
        XCTAssertTrue(text.contains("padding(.bottom, 5)"), "the rails keep a 5pt bottom inset")
        XCTAssertTrue(text.contains("source: .plan"), "left rail is PLAN")
        XCTAssertTrue(text.contains("source: .actual"), "right rail is ACTUAL")
        XCTAssertFalse(text.contains("categoryList"), "category column is gone")
        XCTAssertTrue(
            text.contains("HStack(alignment: .top, spacing: 0)"),
            "PLAN and ACTUAL share one top edge"
        )
        XCTAssertTrue(
            text.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"),
            "each rail fills the shared height"
        )
        XCTAssertFalse(text.contains("GOOGLE CALENDAR"), "title bar must not say GOOGLE CALENDAR")
        XCTAssertFalse(text.contains("nowKick"), "nowKick is gone")
        XCTAssertFalse(text.contains("Text(store.syncLabel)"), "sync status is not in CaptureView")
    }

    func testDualColumnEqualRowsWithoutGearRow() throws {
        let text = try captureView()
        let rails = try slice(text, from: "GeometryReader { _ in", to: "private var footer")
        XCTAssertTrue(rails.contains("source: .plan"), "left rail is PLAN")
        XCTAssertTrue(rails.contains("source: .actual"), "right rail is ACTUAL")
        XCTAssertFalse(text.contains("categoryList"), "category column is gone")
        XCTAssertFalse(text.contains("nowH"), "NOW/gear row height is gone")
        XCTAssertFalse(text.contains("nowRowHeight"), "the rails have no NOW row")
        XCTAssertFalse(text.contains("groups.count + 1"), "sit is not a category row")
        XCTAssertFalse(text.contains("ForEach(store.groups)"), "group rows left capture")
        let footer = try slice(text, from: "private var footer", to: "private var postureElapsed")
        XCTAssertTrue(footer.contains("sitChip"), "sit chip sits in the footer")
        XCTAssertFalse(footer.contains("settingsRow"), "gear left the footer")
        XCTAssertTrue(text.contains("padding(.bottom, 5)"), "the rails keep a 5pt bottom inset")
        XCTAssertFalse(text.contains("padding(.bottom, -"), "the rails must not hang into the home inset")
    }

    func testNoteFieldSpansFullTitleWidth() throws {
        let text = try captureView()
        let titleBar = try slice(text, from: "private var titleBar", to: "private var noteField")
        let note = try slice(text, from: "private var noteField", to: "private var showNoteField")
        XCTAssertTrue(
            titleBar.contains("if showNoteField"),
            "the field still opens under the title"
        )
        XCTAssertTrue(
            note.contains(".frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)"),
            "note field spans full title width"
        )
        XCTAssertTrue(note.contains("TextField(\"note\""), "note is a TextField")
        XCTAssertTrue(note.contains(".submitLabel(.done)"), "note submitLabel is Done")
        XCTAssertFalse(note.contains("axis: .vertical"), "note field is a single line")
        XCTAssertFalse(note.contains("Button(\"Done\")"), "no Done keyboard bar on the field")
        XCTAssertFalse(text.contains("axis: .vertical"), "note field must stay single-line so the key is Done")
        XCTAssertFalse(text.contains("Button(\"Done\")"), "keyboard Done bar is back")
        XCTAssertTrue(
            text.contains("store.open != nil && (editingNote || focus == .note)"),
            "the field stays up only while editing an open block"
        )
        XCTAssertTrue(text.contains("onOpenTap: beginNoteEdit"), "the rail still opens the field")
        XCTAssertFalse(titleBar.contains("headerActions"), "title bar has no STOP/SPLIT column")
        XCTAssertFalse(titleBar.contains("outlineChip"), "title bar has no STOP/SPLIT chips")
        XCTAssertFalse(titleBar.contains("\"ADD NOTE\""), "ADD NOTE chip is gone")
    }

    func testStopAndSplitLiveOnTheRunningCategory() throws {
        let text = try captureView()
        let titleBar = try slice(text, from: "private var titleBar", to: "private var noteField")
        XCTAssertFalse(text.contains("headerActions"), "STOP/SPLIT chips are gone")
        XCTAssertFalse(text.contains("stopButton"), "STOP chip is gone")
        XCTAssertFalse(text.contains("splitButton"), "SPLIT chip is gone")
        XCTAssertFalse(text.contains("outlineChip(\"STOP\""), "STOP chip is gone")
        XCTAssertFalse(text.contains("outlineChip(\"SPLIT\""), "SPLIT chip is gone")
        XCTAssertFalse(titleBar.contains("store.endDay()"), "title bar does not stop")
        XCTAssertFalse(titleBar.contains("store.openSplit()"), "title bar does not split")
        XCTAssertFalse(
            text.contains("store.open != nil || store.sit != nil"),
            "a running sit must not show a STOP chip"
        )
        XCTAssertFalse(text.contains("runningCategoryMenu"), "category menu left capture")
        XCTAssertFalse(text.contains("proposeFromRow"), "row tap left capture")
        XCTAssertFalse(text.contains("store.openSplit()"), "capture has no split control")
        XCTAssertTrue(text.contains("source: .plan"), "left rail is PLAN")
        XCTAssertTrue(text.contains("source: .actual"), "right rail is ACTUAL")
        XCTAssertTrue(text.contains("beginNoteEdit()"), "the actual rail still opens the field")
        XCTAssertTrue(text.contains("onOpenTap: beginNoteEdit"), "open actual block opens the note")
        XCTAssertFalse(text.contains("\"ADD NOTE\""), "ADD NOTE chip is gone")
        XCTAssertFalse(text.contains("onLongPressGesture"), "split must not fire on long press alone")
        XCTAssertFalse(
            text.contains("if store.open != nil { store.openSplit() }"),
            "title must not open SPLIT"
        )
    }

    func testBannerBottomRuleAndRunningRowElapsed() throws {
        let text = try captureView()
        let titleBar = try slice(text, from: "private var titleBar", to: "private var noteField")
        XCTAssertLessThan(
            text.range(of: "if let banner = store.banner")!.lowerBound,
            text.range(of: "titleBar")!.lowerBound,
            "banner stays at the top of CaptureView"
        )
        XCTAssertTrue(text.contains("multilineTextAlignment(.center)"), "banner is centered")
        XCTAssertFalse(
            titleBar.contains("overlay(alignment: .bottom)"),
            "title bar has no 2pt bottom rule"
        )
        XCTAssertFalse(
            text.contains("overlay(alignment: .bottom)"),
            "the rails have no 2pt bottom rule"
        )
        XCTAssertTrue(text.contains("source: .plan"), "left rail is PLAN")
        XCTAssertTrue(text.contains("source: .actual"), "right rail is ACTUAL")
        XCTAssertFalse(text.contains("categoryList"), "category column is gone")
        XCTAssertFalse(text.contains("ForEach(0..<stops"), "scrub dots left capture")
        XCTAssertFalse(
            text.contains("Rectangle().fill(Theme.accent).frame(width: 4)"),
            "running category must not keep a red leading bar"
        )
    }

    private func captureView() throws -> String {
        let ios = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: ios.appendingPathComponent("TimeTap/Views/CaptureView.swift"),
            encoding: .utf8
        )
    }

    private func slice(_ text: String, from: String, to: String) throws -> Substring {
        let start = try XCTUnwrap(text.range(of: from), "missing \(from)")
        let end = try XCTUnwrap(text.range(of: to), "missing \(to)")
        XCTAssertLessThan(start.lowerBound, end.lowerBound, "\(from) must precede \(to)")
        return text[start.lowerBound..<end.lowerBound]
    }
}
