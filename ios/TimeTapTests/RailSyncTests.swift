import XCTest
@testable import TimeTap

@MainActor
final class RailSyncTests: TimeTapTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
    }

    func testTodayRowPutsSyncLabelTrailing() throws {
        let text = try readIOS("TimeTap/Views/DayRailView.swift")
        let todayStart = try XCTUnwrap(
            text.range(of: "HStack(alignment: .firstTextBaseline"),
            "TODAY row is no longer an HStack"
        )
        let bodyStart = try XCTUnwrap(
            text.range(of: "GeometryReader { bodyGeo"),
            "TODAY row lost its trailing edge against the rail body"
        )
        XCTAssertLessThan(
            todayStart.lowerBound,
            bodyStart.lowerBound,
            "TODAY row HStack must sit above the rail body"
        )
        let today = text[todayStart.lowerBound..<bodyStart.lowerBound]
        let start = try XCTUnwrap(
            today.range(of: "startLabel"),
            "TODAY row lost the leading startLabel"
        )
        let spacer = try XCTUnwrap(
            today.range(of: "Spacer"),
            "TODAY row lost the Spacer that pushes sync trailing"
        )
        let sync = try XCTUnwrap(
            today.range(of: "Text(store.syncLabel.uppercased())"),
            "TODAY row lost the trailing sync label"
        )
        XCTAssertLessThan(
            start.lowerBound,
            spacer.lowerBound,
            "startLabel must lead the TODAY row"
        )
        XCTAssertLessThan(
            spacer.lowerBound,
            sync.lowerBound,
            "syncLabel must trail the TODAY Spacer"
        )
        let beforeSync = today[..<sync.lowerBound]
        XCTAssertTrue(
            beforeSync.contains("Theme.font(11, weight: .bold)"),
            "TODAY start label must be 11pt bold"
        )
        let afterSync = today[sync.upperBound...]
        XCTAssertTrue(
            afterSync.contains("Theme.font(11"),
            "syncLabel font left Theme.font(11)"
        )
        XCTAssertTrue(
            afterSync.contains("weight: .bold"),
            "syncLabel must be bold"
        )
        XCTAssertTrue(
            afterSync.contains("store.syncFailed ? Theme.accentOn : Theme.mute"),
            "syncLabel color left failed-accent / mute"
        )
        XCTAssertTrue(
            afterSync.contains("multilineTextAlignment(.trailing)"),
            "syncLabel lost trailing alignment"
        )
        XCTAssertTrue(
            today.contains("store.syncLabel.uppercased()"),
            "sync status must render in all caps"
        )
    }

    func testNowMarkerKeepsBottomPadding() throws {
        let text = try readIOS("TimeTap/Views/DayRailView.swift")
        XCTAssertTrue(text.contains("Theme.font(11, weight: .bold)"), "TODAY, SYNCED, and NOW ▲ are 11pt bold")
        XCTAssertFalse(text.contains("Theme.font(10, weight: .semibold)"), "chrome labels left 10pt semibold")
        XCTAssertFalse(text.contains("Theme.font(10, weight: .bold)"), "NOW ▲ left 10pt")
        let now = try XCTUnwrap(text.range(of: "NOW ▲"), "NOW ▲ marker left the day rail")
        let pad = try XCTUnwrap(
            text.range(of: "padding(.bottom, 2)"),
            "NOW ▲ lost padding(.bottom, 2)"
        )
        XCTAssertLessThan(
            now.lowerBound,
            pad.lowerBound,
            "NOW ▲ must keep padding(.bottom, 2) on the marker"
        )
        XCTAssertTrue(text.contains("var nowRowHeight: CGFloat"), "NOW ▲ has its own row height")
        XCTAssertTrue(text.contains("alignment: .topLeading"), "NOW ▲ lines up with the top of the gear")
        XCTAssertTrue(
            text[now.lowerBound...].contains("padding(.top, 12)"),
            "NOW ▲ keeps a 12pt gap under the calendar"
        )
        XCTAssertFalse(text.contains("padding(.bottom, 8)"), "NOW ▲ must not sit on an 8pt rail inset")
        XCTAssertFalse(text.contains("\"gearshape\""), "settings gear left the day rail")
        XCTAssertFalse(text.contains("store.showSettings = true"), "settings gear left the day rail")
    }

    func testCaptureViewDoesNotShowSyncLabel() throws {
        let text = try readIOS("TimeTap/Views/CaptureView.swift")
        XCTAssertFalse(
            text.contains("Text(store.syncLabel"),
            "sync status returned to the NOW panel"
        )
    }

    func testPaintSyncPinsShortLabels() throws {
        let text = try readIOS("TimeTap/Services/TapStore.swift")
        XCTAssertTrue(
            text.contains("syncLabel = \"sync failed\""),
            "paintSync lost the sync failed label"
        )
        XCTAssertTrue(
            text.contains("syncLabel = \"waiting\""),
            "paintSync lost the waiting label"
        )
        XCTAssertTrue(
            text.contains("syncLabel = \"synced\""),
            "paintSync lost the synced label"
        )
        XCTAssertTrue(
            text.contains("syncLabel = \"syncing · \\(queue.count)\""),
            "paintSync lost the syncing queue-count label"
        )
        XCTAssertTrue(
            text.contains("\"\\(dead.count) set aside\""),
            "paintSync lost the set-aside count label"
        )
        XCTAssertTrue(
            text.contains("\"\\(dead.count) set aside · retrying\""),
            "paintSync lost the set-aside retrying label"
        )
        XCTAssertFalse(
            text.contains("GOOGLE CALENDAR"),
            "sync status became a calendar label"
        )
        XCTAssertFalse(
            text.contains("NOW · SINCE"),
            "sync status became a NOW · SINCE clock"
        )
        XCTAssertFalse(
            text.contains("var nowKick"),
            "nowKick came back on TapStore"
        )
    }

    func testColdStoreDoesNotClaimSynced() {
        GoogleAuth.testHasSession = nil
        let store = TapStore()
        XCTAssertFalse(store.sessionReady)
        XCTAssertTrue(
            store.syncLabel.contains("waiting"),
            "cold store dropped waiting before a session exists"
        )
        XCTAssertFalse(
            store.syncLabel.contains("synced"),
            "cold store claimed synced before a session exists"
        )
    }

    func testSetAsideDoesNotClaimRetryingWhenQueueIsEmpty() {
        if let data = try? JSONEncoder().encode([
            DeadEntry(
                at: 1_700_000_000_000,
                why: "insert failed",
                op: Op(id: "o1", type: "openActual", ref: "abcdefghijklmnop", key: "DW"),
                key: "DW",
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
        XCTAssertTrue(store.queue.isEmpty)
        XCTAssertEqual(
            store.syncLabel,
            "1 set aside",
            "empty-queue set-aside must stay 'N set aside'"
        )
        XCTAssertFalse(
            store.syncLabel.contains("retrying"),
            "empty-queue set-aside claimed retrying"
        )
    }

    func testReadmeKeepsLiveActivitySentences() throws {
        let text = try readIOS("README.md")
        let flat = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        XCTAssertTrue(
            flat.contains("STOP closes the running block only"),
            "README dropped STOP-closes-the-running-block-only"
        )
        XCTAssertTrue(
            flat.contains("Sitting has its own start/stop"),
            "README dropped sitting's own start/stop"
        )
        XCTAssertTrue(
            flat.contains("Lock Screen and Dynamic Island"),
            "README dropped Lock Screen and Dynamic Island"
        )
        XCTAssertTrue(
            flat.contains("Enable Live Activities for timetap"),
            "README dropped Enable Live Activities for timetap"
        )
        XCTAssertTrue(
            flat.contains("Home Screen widgets"),
            "README dropped the Home Screen widgets exclusion"
        )
    }

    private func readIOS(_ rel: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(rel),
            encoding: .utf8
        )
    }
}
