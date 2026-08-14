import XCTest
@testable import TimeTap

@MainActor
final class NowPanelTests: TimeTapTestCase {
    func testNowPanelTitleAndSettingsGear() throws {
        let text = try captureView()
        let nowPanel = try slice(text, from: "private var nowPanel", to: "private var noteField")
        XCTAssertTrue(nowPanel.contains("NOTHING RUNNING"), "idle title is NOTHING RUNNING")
        XCTAssertTrue(nowPanel.contains(".uppercased()"), "running title is the category in uppercase")
        XCTAssertFalse(nowPanel.contains("settingsButton"), "gear left the title row")
        XCTAssertFalse(nowPanel.contains("gearshape"), "gear left the NOW panel")
        XCTAssertTrue(text.contains("gearshape"), "gear sits under the sit row")
        XCTAssertTrue(text.contains("store.showSettings = true"), "gear opens settings")
        XCTAssertLessThan(
            text.range(of: ".id(\"sit\")")!.lowerBound,
            text.range(of: "settingsRow")!.lowerBound,
            "gear sits under NOT SITTING"
        )
        let settings = try slice(text, from: "private var settingsRow", to: "private var sitChip")
        XCTAssertTrue(settings.contains("alignment: .topTrailing"), "gear sits on the top right")
        XCTAssertTrue(settings.contains("padding(.top, 12)"), "gear keeps a 12pt gap under NOT SITTING")
        XCTAssertTrue(text.contains("nowRowHeight: nowH"), "calendar ends on the sit row")
        XCTAssertTrue(text.contains("let nowH = rowH - 25"), "NOW/gear row stays 25pt shorter than a list row")
        XCTAssertTrue(text.contains("padding(.bottom, 5)"), "dual columns keep a 5pt bottom inset")
        XCTAssertTrue(
            text.contains("HStack(alignment: .bottom, spacing: 0)"),
            "calendar and categories share one bottom edge"
        )
        XCTAssertTrue(
            text.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"),
            "the calendar column fills the shared height"
        )
        XCTAssertFalse(text.contains("GOOGLE CALENDAR"), "NOW panel must not say GOOGLE CALENDAR")
        XCTAssertFalse(text.contains("nowKick"), "nowKick is gone")
        XCTAssertFalse(text.contains("Text(store.syncLabel)"), "sync status is not in CaptureView")
    }

    func testDualColumnEqualRowsAndNowGearGap() throws {
        let text = try captureView()
        let list = try slice(text, from: "private func categoryList", to: "private var addRow")
        XCTAssertTrue(
            text.contains("categoryList(height: geo.size.height, nowH: nowH)"),
            "category list must receive the shared NOW/gear row height"
        )
        XCTAssertTrue(text.contains("let nowH = rowH - 25"), "NOW/gear row stays 25pt shorter than a counted row")
        XCTAssertTrue(text.contains("nowRowHeight: nowH"), "calendar NOW row matches the gear row")
        XCTAssertTrue(text.contains("categories.count + 3"), "nowH still counts add, sit, and settings")
        XCTAssertTrue(list.contains("categories.count + 2"), "add, categories, and sit share one row height")
        XCTAssertTrue(list.contains("(height - nowH)"), "list rows fill the space above the gear")
        XCTAssertTrue(
            list.contains("min(rowH * CGFloat(store.categories.count + 1), max(0, height - nowH - rowH))"),
            "the category scroll must not leave a gap above NOT SITTING"
        )
        XCTAssertTrue(list.contains("sitChip"), "sit stays in the category column")
        XCTAssertTrue(
            list.contains(".frame(maxWidth: .infinity, minHeight: rowH, maxHeight: rowH)"),
            "NOT SITTING uses the same row height as the category buttons"
        )
        XCTAssertTrue(
            list.contains(".frame(maxWidth: .infinity, minHeight: nowH, maxHeight: nowH)"),
            "the gear row uses nowH, not a leftover flex gap"
        )
        XCTAssertLessThan(
            list.range(of: "height - nowH - rowH")!.lowerBound,
            list.range(of: "sitChip")!.lowerBound,
            "sit sits under the category scroll, not inside it"
        )
        XCTAssertLessThan(
            list.range(of: ".id(\"sit\")")!.lowerBound,
            list.range(of: "settingsRow")!.lowerBound,
            "gear sits under NOT SITTING"
        )
        XCTAssertTrue(text.contains("padding(.bottom, 5)"), "dual columns keep a 5pt bottom inset")
        XCTAssertFalse(text.contains("padding(.bottom, -"), "dual columns must not hang into the home inset")
        XCTAssertFalse(text.contains(".clipped()"), "the calendar column must not clip NOW ▲")
        let settings = try slice(text, from: "private var settingsRow", to: "private var sitChip")
        XCTAssertTrue(settings.contains("padding(.top, 12)"), "gear keeps a 12pt gap under NOT SITTING")
        XCTAssertTrue(settings.contains("alignment: .topTrailing"), "gear sits on the top right")
    }

    func testDurationSharesTheTitleRow() throws {
        let text = try captureView()
        let nowPanel = try slice(text, from: "private var nowPanel", to: "private var noteField")
        let duration = try slice(
            String(nowPanel),
            from: "HStack(alignment: .center, spacing: 12)",
            to: "Text(\"—\")"
        )
        XCTAssertTrue(duration.contains(".uppercased()"), "category label shares the elapsed HStack")
        XCTAssertTrue(duration.contains("elapsedLabel"), "duration is elapsed")
        XCTAssertLessThan(
            duration.range(of: ".uppercased()")!.lowerBound,
            duration.range(of: "elapsedLabel")!.lowerBound,
            "elapsed sits after the category label"
        )
        XCTAssertLessThan(
            duration.range(of: ".uppercased()")!.lowerBound,
            duration.range(of: "Spacer(minLength: 8)")!.lowerBound,
            "a spacer sits after the category label"
        )
        XCTAssertLessThan(
            duration.range(of: "Spacer(minLength: 8)")!.lowerBound,
            duration.range(of: "elapsedLabel")!.lowerBound,
            "elapsed is right-justified"
        )
        XCTAssertTrue(
            duration.contains(".font(.system(size: 48, weight: .heavy))"),
            "elapsed is 48pt heavy"
        )
        XCTAssertFalse(duration.contains("addNoteButton"), "ADD NOTE left the title row")
        XCTAssertFalse(duration.contains("showAddNote"), "ADD NOTE left the title row")
        XCTAssertFalse(nowPanel.contains("\"ADD NOTE\""), "ADD NOTE is a running-row menu item")
        XCTAssertFalse(
            duration.contains("maxWidth: .infinity"),
            "title row must not stretch a full-width control"
        )
        XCTAssertEqual(
            nowPanel.components(separatedBy: "HStack(alignment: .center").count - 1,
            1,
            "title and elapsed must share one HStack, not stacked rows"
        )
        XCTAssertTrue(
            nowPanel.contains("Spacer(minLength: 8)"),
            "elapsed is pushed to the trailing edge"
        )
        XCTAssertTrue(
            nowPanel.contains(".frame(maxWidth: .infinity, alignment: .leading)"),
            "title row must take the full NOW width"
        )
    }

    func testNoteFieldSpansFullNowWidth() throws {
        let text = try captureView()
        let nowPanel = try slice(text, from: "private var nowPanel", to: "private var noteField")
        let note = try slice(text, from: "private var noteField", to: "private var showNoteField")
        XCTAssertLessThan(
            nowPanel.range(of: "elapsedLabel")!.lowerBound,
            nowPanel.range(of: "noteField")!.lowerBound,
            "note field sits under the duration row"
        )
        XCTAssertTrue(
            nowPanel.contains("if showNoteField"),
            "the field still opens under the duration row"
        )
        XCTAssertTrue(
            note.contains(".frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)"),
            "note field spans full NOW width"
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
        XCTAssertFalse(nowPanel.contains("headerActions"), "NOW has no STOP/SPLIT column")
        XCTAssertFalse(nowPanel.contains("outlineChip"), "NOW has no STOP/SPLIT chips")
    }

    func testStopAndSplitLiveOnTheRunningCategory() throws {
        let text = try captureView()
        let nowPanel = try slice(text, from: "private var nowPanel", to: "private var noteField")
        XCTAssertFalse(text.contains("headerActions"), "STOP/SPLIT chips are gone")
        XCTAssertFalse(text.contains("stopButton"), "STOP chip is gone")
        XCTAssertFalse(text.contains("splitButton"), "SPLIT chip is gone")
        XCTAssertFalse(text.contains("outlineChip(\"STOP\""), "STOP chip is gone")
        XCTAssertFalse(text.contains("outlineChip(\"SPLIT\""), "SPLIT chip is gone")
        XCTAssertFalse(nowPanel.contains("store.endDay()"), "NOW does not stop")
        XCTAssertFalse(nowPanel.contains("store.openSplit()"), "NOW does not split")
        XCTAssertFalse(
            text.contains("store.open != nil || store.sit != nil"),
            "a running sit must not show a STOP chip"
        )
        XCTAssertTrue(text.contains("runningCategoryMenu(enabled: running)"), "long press is only on the running row")
        XCTAssertTrue(text.contains("store.openSplit()"), "menu Split opens split")
        XCTAssertTrue(text.contains("Button(\"Split\""), "Split is a menu item")
        XCTAssertTrue(text.contains("Button(\"Add note\""), "Add note is a menu item")
        XCTAssertTrue(text.contains(".contextMenu"), "running row long press is a menu")
        XCTAssertTrue(text.contains("beginNoteEdit()"), "menu Add note opens the field")
        XCTAssertTrue(text.contains("store.tapCategory(cat.key)"), "tap still goes through tapCategory")
        XCTAssertTrue(text.contains("Does not stop sitting"), "tap-to-stop leaves sitting")
        XCTAssertTrue(text.contains("Long press for split and add note"), "VoiceOver names the long press")
        XCTAssertFalse(text.contains("\"ADD NOTE\""), "ADD NOTE chip is gone")
        XCTAssertFalse(text.contains("onLongPressGesture"), "split must not fire on long press alone")
        XCTAssertFalse(
            text.contains("if store.open != nil { store.openSplit() }"),
            "title/elapsed must not open SPLIT"
        )
    }

    func testBannerBottomRuleAndRunningRowElapsed() throws {
        let text = try captureView()
        let nowPanel = try slice(text, from: "private var nowPanel", to: "private var noteField")
        let row = try slice(text, from: "private func categoryRow", to: "private var categoryWidthProbe")
        XCTAssertLessThan(
            text.range(of: "if let banner = store.banner")!.lowerBound,
            text.range(of: "nowPanel")!.lowerBound,
            "banner stays at the top of CaptureView"
        )
        XCTAssertTrue(text.contains("multilineTextAlignment(.center)"), "banner is centered")
        XCTAssertFalse(
            nowPanel.contains("overlay(alignment: .bottom)"),
            "NOW panel has no 2pt bottom rule"
        )
        XCTAssertFalse(
            text.contains("overlay(alignment: .bottom)"),
            "dual column has no 2pt bottom rule"
        )
        XCTAssertTrue(text.contains("let running = store.open?.key == cat.key"), "running row must show elapsed")
        XCTAssertTrue(text.contains("elapsed: elapsedLabel"), "running row elapsed is the same clock")
        XCTAssertTrue(row.contains("if running"), "running category row has elapsed")
        XCTAssertTrue(row.contains("Text(elapsed)"), "running category row shows elapsed")
        XCTAssertTrue(
            row.contains("weight: running ? .bold : .semibold"),
            "running category label is bold"
        )
        XCTAssertFalse(
            text.contains("Rectangle().fill(Theme.accent).frame(width: 4)"),
            "running category must not keep a red leading bar"
        )
        XCTAssertFalse(
            row.contains("frame(width: 4)"),
            "category row has no 4px leading bar"
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
