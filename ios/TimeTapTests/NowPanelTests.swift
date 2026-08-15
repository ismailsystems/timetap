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
        XCTAssertFalse(text.contains("settingsRow"), "gear left the category column")
        XCTAssertFalse(text.contains("nowRowHeight"), "NOW row left the dual column")
        XCTAssertTrue(text.contains("padding(.bottom, 5)"), "dual columns keep a 5pt bottom inset")
        XCTAssertTrue(
            text.contains("HStack(alignment: .top, spacing: 0)"),
            "calendar and categories share one top edge"
        )
        XCTAssertTrue(
            text.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"),
            "the calendar column fills the shared height"
        )
        XCTAssertFalse(text.contains("GOOGLE CALENDAR"), "title bar must not say GOOGLE CALENDAR")
        XCTAssertFalse(text.contains("nowKick"), "nowKick is gone")
        XCTAssertFalse(text.contains("Text(store.syncLabel)"), "sync status is not in CaptureView")
    }

    func testDualColumnEqualRowsWithoutGearRow() throws {
        let text = try captureView()
        let list = try slice(text, from: "private func categoryList", to: "private var footer")
        XCTAssertTrue(
            text.contains("categoryList(height: geo.size.height)"),
            "category list receives the column height"
        )
        XCTAssertFalse(text.contains("nowH"), "NOW/gear row height is gone")
        XCTAssertFalse(text.contains("nowRowHeight"), "calendar has no NOW row")
        XCTAssertTrue(list.contains("groups.count + 1"), "groups and sit share one row height")
        XCTAssertTrue(
            list.contains("min(rowH * CGFloat(store.groups.count), max(0, height - rowH))"),
            "the category scroll must not leave a gap above NOT SITTING"
        )
        XCTAssertTrue(list.contains("sitChip"), "sit stays in the category column")
        XCTAssertTrue(
            list.contains(".frame(maxWidth: .infinity, minHeight: rowH, maxHeight: rowH)"),
            "NOT SITTING uses the same row height as the category buttons"
        )
        XCTAssertFalse(list.contains("settingsRow"), "gear left the category column")
        XCTAssertLessThan(
            list.range(of: "height - rowH")!.lowerBound,
            list.range(of: "sitChip")!.lowerBound,
            "sit sits under the category scroll, not inside it"
        )
        XCTAssertTrue(text.contains("padding(.bottom, 5)"), "dual columns keep a 5pt bottom inset")
        XCTAssertFalse(text.contains("padding(.bottom, -"), "dual columns must not hang into the home inset")
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
        XCTAssertFalse(titleBar.contains("\"ADD NOTE\""), "ADD NOTE is a running-row menu item")
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
        XCTAssertTrue(text.contains("runningCategoryMenu(enabled: running, stop:"), "long press is only on the running row")
        XCTAssertTrue(text.contains("store.openSplit()"), "menu Split opens split")
        XCTAssertTrue(text.contains("Button(\"Stop\""), "Stop is a menu item")
        XCTAssertTrue(text.contains("Button(\"Split\""), "Split is a menu item")
        XCTAssertTrue(text.contains("Button(\"Add note\""), "Add note is a menu item")
        XCTAssertTrue(text.contains(".contextMenu"), "running row long press is a menu")
        XCTAssertTrue(text.contains("beginNoteEdit()"), "menu Add note opens the field")
        XCTAssertTrue(text.contains("store.proposeFromRow(key)"), "tap proposes, then waits 5s")
        XCTAssertTrue(text.contains("store.propose(key)"), "menu Stop still calls propose")
        XCTAssertTrue(text.contains("Does not stop sitting"), "tap-to-stop leaves sitting")
        XCTAssertTrue(text.contains("Long press for stop, split, and add note"), "VoiceOver names the long press")
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
        let row = try slice(text, from: "private func categoryRow", to: "private var categoryWidthProbe")
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
            "dual column has no 2pt bottom rule"
        )
        XCTAssertTrue(text.contains("group.children.first { $0.label == open.key }"), "running row must show elapsed")
        XCTAssertTrue(text.contains("elapsed: elapsedLabel"), "running row elapsed is the same clock")
        XCTAssertTrue(row.contains("if pending || running"), "running and pending rows have a trailing slot")
        XCTAssertTrue(row.contains("Text(elapsed)"), "running category row shows elapsed")
        XCTAssertTrue(
            row.contains("weight: running ? .bold : .semibold"),
            "running category label is bold"
        )
        XCTAssertFalse(
            text.contains("Rectangle().fill(Theme.accent).frame(width: 4)"),
            "running category must not keep a red leading bar"
        )
        XCTAssertTrue(
            row.contains("ForEach(0..<stops"),
            "dots mark how many children you can scrub"
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
