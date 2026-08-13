import XCTest
@testable import TimeTap

@MainActor
final class NowPanelTests: TimeTapTestCase {
    func testNowPanelTitleAndSettingsGear() throws {
        let text = try captureView()
        let nowPanel = try slice(text, from: "private var nowPanel", to: "private var settingsButton")
        let settings = try slice(text, from: "private var settingsButton", to: "private var addNoteButton")
        XCTAssertTrue(nowPanel.contains("NOTHING RUNNING"), "idle title is NOTHING RUNNING")
        XCTAssertTrue(nowPanel.contains(".uppercased()"), "running title is the category in uppercase")
        XCTAssertTrue(nowPanel.contains("settingsButton"), "gear sits on the title row")
        XCTAssertTrue(settings.contains("\"gearshape\""), "settings is a gear")
        XCTAssertTrue(settings.contains("store.showSettings = true"), "gear opens settings")
        XCTAssertFalse(text.contains("GOOGLE CALENDAR"), "NOW panel must not say GOOGLE CALENDAR")
        XCTAssertFalse(text.contains("nowKick"), "nowKick is gone")
        XCTAssertFalse(text.contains("Text(store.syncLabel)"), "sync status is not in CaptureView")
    }

    func testDurationRowKeepsAddNoteBesideElapsed() throws {
        let text = try captureView()
        let nowPanel = try slice(text, from: "private var nowPanel", to: "private var settingsButton")
        let addNote = try slice(text, from: "private var addNoteButton", to: "private var noteField")
        let duration = try slice(
            String(nowPanel),
            from: "HStack(alignment: .center, spacing: 12)",
            to: "Text(\"—\")"
        )
        XCTAssertTrue(duration.contains("elapsedLabel"), "duration is elapsed")
        XCTAssertTrue(
            duration.contains(".font(.system(size: 48, weight: .heavy))"),
            "elapsed is 48pt heavy"
        )
        XCTAssertTrue(duration.contains("if showAddNote"), "ADD NOTE shares the elapsed HStack")
        XCTAssertTrue(duration.contains("addNoteButton"), "ADD NOTE sits to the right of duration")
        XCTAssertLessThan(
            duration.range(of: "elapsedLabel")!.lowerBound,
            duration.range(of: "showAddNote")!.lowerBound,
            "ADD NOTE is after elapsed"
        )
        XCTAssertLessThan(
            duration.range(of: "showAddNote")!.lowerBound,
            duration.range(of: "addNoteButton")!.lowerBound,
            "showAddNote then addNoteButton"
        )
        XCTAssertFalse(
            duration.contains("maxWidth: .infinity"),
            "a full-width ADD NOTE would wrap onto its own row"
        )
        XCTAssertFalse(
            addNote.contains("maxWidth: .infinity"),
            "ADD NOTE is not frame(maxWidth: .infinity)"
        )
        XCTAssertTrue(
            addNote.contains(".frame(minHeight: 44, alignment: .leading)"),
            "ADD NOTE keeps a 44pt floor without taking the row"
        )
        XCTAssertTrue(addNote.contains("\"ADD NOTE\""), "empty note is a button")
        XCTAssertTrue(addNote.contains("beginNoteEdit"), "ADD NOTE opens the field")
        XCTAssertTrue(
            text.contains("store.open != nil && !hasNote && !showNoteField"),
            "ADD NOTE shows only for an open block with no note and no field"
        )
    }

    func testNoteFieldSpansUnderHeaderActions() throws {
        let text = try captureView()
        let nowPanel = try slice(text, from: "private var nowPanel", to: "private var settingsButton")
        let note = try slice(text, from: "private var noteField", to: "private var headerActions")
        XCTAssertLessThan(
            nowPanel.range(of: "headerActions")!.lowerBound,
            nowPanel.range(of: "noteField")!.lowerBound,
            "note field is a sibling under STOP and SPLIT"
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
    }

    func testHeaderActionsAreStopAboveSplitForOpenOnly() throws {
        let text = try captureView()
        let nowPanel = try slice(text, from: "private var nowPanel", to: "private var settingsButton")
        let header = try slice(text, from: "private var headerActions", to: "private var splitButton")
        let stop = try slice(text, from: "private var stopButton", to: "private var showNoteField")
        let split = try slice(text, from: "private var splitButton", to: "private var stopButton")
        XCTAssertNotNil(
            nowPanel.range(of: #"if store\.open != nil \{\s+headerActions"#, options: .regularExpression),
            "headerActions only renders if store.open != nil"
        )
        XCTAssertFalse(nowPanel.contains("store.sit"), "STOP is not shown for sitting alone")
        XCTAssertFalse(
            text.contains("store.open != nil || store.sit != nil"),
            "STOP must not appear for sitting alone"
        )
        XCTAssertTrue(header.contains("VStack"), "STOP stacks above SPLIT")
        XCTAssertLessThan(
            header.range(of: "stopButton")!.lowerBound,
            header.range(of: "splitButton")!.lowerBound,
            "STOP sits above SPLIT"
        )
        XCTAssertTrue(
            header.contains(".containerRelativeFrame(.horizontal, alignment: .trailing)"),
            "STOP/SPLIT take a trailing quarter"
        )
        XCTAssertTrue(header.contains("width / 4"), "headerActions width is 1/4")
        XCTAssertTrue(stop.contains("outlineChip(\"STOP\""), "STOP is an outline chip")
        XCTAssertTrue(stop.contains("store.endDay()"), "STOP ends the day")
        XCTAssertTrue(stop.contains("Does not stop sitting"), "STOP does not stop sitting")
        XCTAssertTrue(split.contains("outlineChip(\"SPLIT\""), "SPLIT is an outline chip")
    }

    func testBannerBottomRuleAndRunningRowElapsed() throws {
        let text = try captureView()
        let nowPanel = try slice(text, from: "private var nowPanel", to: "private var settingsButton")
        let row = try slice(text, from: "private func categoryRow", to: "private var categoryWidthProbe")
        XCTAssertLessThan(
            text.range(of: "if let banner = store.banner")!.lowerBound,
            text.range(of: "nowPanel")!.lowerBound,
            "banner stays at the top of CaptureView"
        )
        XCTAssertTrue(text.contains("multilineTextAlignment(.center)"), "banner is centered")
        XCTAssertGreaterThanOrEqual(
            text.components(separatedBy: "overlay(alignment: .bottom)").count - 1,
            2,
            "dual column must close with the same bottom rule as the now panel"
        )
        XCTAssertTrue(
            nowPanel.contains("overlay(alignment: .bottom)"),
            "NOW panel keeps the 2pt bottom rule"
        )
        XCTAssertTrue(text.contains("running: store.open?.key == cat.key"), "running row must show elapsed")
        XCTAssertTrue(text.contains("elapsed: elapsedLabel"), "running row elapsed is the same clock")
        XCTAssertTrue(row.contains("if running"), "running category row has elapsed")
        XCTAssertTrue(row.contains("Text(elapsed)"), "running category row shows elapsed")
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
