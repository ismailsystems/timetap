import XCTest
@testable import TimeTap

@MainActor
final class LASyncTests: TimeTapTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        ApplyOps.resetForTests()
    }

    func testApplySourcePinsLifecycle() throws {
        let text = try readIOS("TimeTap/LiveActivity/RunningBlockSync.swift")
        XCTAssertTrue(text.contains("protocol LiveActivityRuntime"), "apply must go through a testable runtime")
        XCTAssertTrue(
            text.contains("struct ActivityKitLiveActivityRuntime"),
            "production must still talk to ActivityKit"
        )
        XCTAssertTrue(
            text.contains("nonisolated(unsafe) static var runtime"),
            "tests replace RunningBlockSync.runtime"
        )
        XCTAssertTrue(
            text.contains("ActivityKitLiveActivityRuntime()"),
            "default runtime is ActivityKit"
        )
        XCTAssertTrue(
            text.contains("await apply(state, runtime: runtime)"),
            "apply(_:) must forward to the injected runtime"
        )
        XCTAssertTrue(
            text.contains("guard runtime.areEnabled else { return }"),
            "apply must bail when Live Activities are off"
        )
        XCTAssertTrue(
            text.contains("current.state == .active || current.state == .stale"),
            "active or stale is the update path"
        )
        XCTAssertTrue(
            text.contains("await runtime.update(id: current.id, state: state)"),
            "active/stale path must update the first activity"
        )
        XCTAssertTrue(
            text.contains("existing.dropFirst()"),
            "update path must end extra activities"
        )
        XCTAssertTrue(
            text.contains("try await runtime.request(state)"),
            "missing activity must request"
        )
        XCTAssertTrue(
            text.contains("try? await runtime.request(state)"),
            "request must catch and retry once"
        )
        XCTAssertTrue(text.contains("} catch {"), "missing request must retry in catch")
        XCTAssertTrue(text.contains("pushType: nil"), "request must not use a push type")
        XCTAssertTrue(text.contains("staleDate: nil"), "we do not mark our own 8h stale")
        XCTAssertTrue(
            text.contains("dismissalPolicy: .immediate"),
            "end must dismiss immediately"
        )
        XCTAssertTrue(
            text.contains("Activity.request"),
            "ActivityKit adapter still calls Activity.request"
        )
        XCTAssertLessThan(
            try range(text, "guard runtime.areEnabled").lowerBound,
            try range(text, "if let state").lowerBound,
            "disabled devices must bail before update or request"
        )
        XCTAssertLessThan(
            try range(text, "for extra in existing").lowerBound,
            try range(text, "runtime.request(state)").lowerBound,
            "leftovers must end before request"
        )
    }

    func testSignOutAppliesNilState() throws {
        let signOut = try sliceFunction(
            readIOS("TimeTap/Services/TapStore.swift"),
            named: "func signOut()"
        )
        XCTAssertTrue(
            signOut.contains("RunningBlockSync.apply(nil)"),
            "sign-out still ends the Live Activity"
        )
        XCTAssertFalse(
            signOut.contains("syncLiveActivity()"),
            "sign-out must end, not refresh"
        )
    }

    func testSyncLiveActivitySourcePinsAlwaysOn() throws {
        let sync = try sliceFunction(
            readIOS("TimeTap/Services/TapStore.swift"),
            named: "private func syncLiveActivity()",
            includingDoc: true
        )
        XCTAssertTrue(
            sync.contains("Always on: one is sitting or standing. Ends only on sign-out."),
            "Live Activity stays up while signed in"
        )
        XCTAssertTrue(
            sync.contains("NSClassFromString(\"XCTestCase\") == nil"),
            "tests must not start Live Activities"
        )
        XCTAssertTrue(
            sync.contains("guard NSClassFromString(\"XCTestCase\") == nil else { return }"),
            "XCTest must return before ActivityKit"
        )
        XCTAssertTrue(
            sync.contains("if sit == nil && standStartMs == nil"),
            "standing seed is sit == nil && standStartMs == nil"
        )
        XCTAssertTrue(
            sync.contains("standStartMs = clock()"),
            "empty standing bout must seed standStartMs from clock()"
        )
        XCTAssertTrue(sync.contains("key: open?.key"), "ContentState key comes from open")
        XCTAssertTrue(
            sync.contains("face: open.map { labelFor($0.key) }"),
            "ContentState face comes from open"
        )
        XCTAssertTrue(
            sync.contains("hex: open.flatMap { catByKey[$0.key]?.hex }"),
            "ContentState hex comes from open"
        )
        XCTAssertTrue(
            sync.contains("startMs: open?.startMs"),
            "ContentState startMs comes from open"
        )
        XCTAssertTrue(
            sync.contains("sitting: sit != nil"),
            "ContentState sitting is sit != nil"
        )
        XCTAssertTrue(
            sync.contains("sitStartMs: sit?.startMs"),
            "ContentState sitStartMs comes from sit"
        )
        XCTAssertTrue(
            sync.contains("standStartMs: standStartMs"),
            "ContentState standStartMs comes from the store"
        )
        XCTAssertTrue(
            sync.contains("RunningBlockSync.apply(state)"),
            "sync applies a non-nil ContentState"
        )
        XCTAssertFalse(
            sync.contains("open == nil && sit == nil"),
            "standing still keeps the Live Activity"
        )
        XCTAssertLessThan(
            try range(sync, "NSClassFromString").lowerBound,
            try range(sync, "standStartMs = clock()").lowerBound,
            "XCTest guard must run before seeding or apply"
        )
    }

    func testSyncLiveActivityCallSites() throws {
        let tap = try readIOS("TimeTap/Services/TapStore.swift")
        let sites: [(marker: String, needle: String, msg: String)] = [
            (
                "func refreshOnReturnNow()",
                "defer { syncLiveActivity() }",
                "return to the app must restart a killed Live Activity"
            ),
            (
                "private func loadPersisted()",
                "syncLiveActivity()",
                "loadPersisted must restore the Live Activity"
            ),
            (
                "func tapCategory(_ key: String)",
                "syncLiveActivity()",
                "tapCategory must sync the Live Activity"
            ),
            (
                "func endDay()",
                "syncLiveActivity()",
                "endDay must sync the Live Activity"
            ),
            (
                "func toggleSit()",
                "syncLiveActivity()",
                "toggleSit must sync the Live Activity"
            ),
            (
                "func stopSit()",
                "syncLiveActivity()",
                "stopSit must sync the Live Activity"
            ),
            (
                "func deleteSit()",
                "syncLiveActivity()",
                "deleteSit must sync the Live Activity"
            ),
            (
                "func applySitEdit()",
                "syncLiveActivity()",
                "applySitEdit must sync the Live Activity"
            ),
            (
                "func takeUndo()",
                "syncLiveActivity()",
                "takeUndo must sync the Live Activity"
            ),
            (
                "func doSplit(key: String)",
                "syncLiveActivity()",
                "doSplit must sync the Live Activity"
            ),
            (
                "private func recatWhole(key: String)",
                "syncLiveActivity()",
                "recatWhole must sync the Live Activity"
            ),
            (
                "private func closeRunningOnCurrentCalendars()",
                "syncLiveActivity()",
                "closeRunningOnCurrentCalendars must sync the Live Activity"
            ),
            (
                "private func adoptServerState(_ st: ServerState, gen: Int)",
                "syncLiveActivity()",
                "adoptServerState must sync the Live Activity"
            ),
            (
                "private func quarantine(_ err: ApplyResult.ApplyError)",
                "syncLiveActivity()",
                "dead-letter clear must sync the Live Activity"
            ),
        ]
        for site in sites {
            let body = try sliceFunction(tap, named: site.marker)
            XCTAssertTrue(body.contains(site.needle), site.msg)
        }
        let dead = try sliceFunction(tap, named: "private func quarantine(_ err: ApplyResult.ApplyError)")
        XCTAssertTrue(dead.contains("if cleared"), "quarantine syncs only when the open or sit was cleared")
        let persist = try range(dead, "if cleared")
        let sync = try range(dead, "syncLiveActivity()")
        XCTAssertLessThan(persist.lowerBound, sync.lowerBound, "cleared then syncLiveActivity")
    }

    func testDoSplitChangesOpenKey() async {
        clearPersisted()
        pinSession()
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("Deep work")
        await store.flushNow()
        XCTAssertEqual(store.open?.key, "Deep work")
        now += 120_000
        store.openSplit()
        store.setSplitWhole(false)
        store.setSplitMinutes(1)
        store.doSplit(key: "Meetings")
        XCTAssertEqual(store.open?.key, "Meetings", "doSplit must change the running key")
    }

    func testApplySitEditSyncsAfterPersistFlush() throws {
        let body = try sliceFunction(
            readIOS("TimeTap/Services/TapStore.swift"),
            named: "func applySitEdit()"
        )
        let persist = try range(body, "persist()")
        let flush = try range(body, "flush()")
        let sync = try range(body, "syncLiveActivity()")
        XCTAssertLessThan(
            persist.lowerBound,
            sync.lowerBound,
            "applySitEdit must sync after persist"
        )
        XCTAssertLessThan(
            flush.lowerBound,
            sync.lowerBound,
            "applySitEdit must sync after flush"
        )
    }

    func testCloseSitAndPersistedStateKeepStandStartMs() throws {
        let tap = try readIOS("TimeTap/Services/TapStore.swift")
        let closeSit = try sliceFunction(tap, named: "private func closeSit(")
        XCTAssertTrue(closeSit.contains("sit = nil"), "closeSit must clear sit")
        XCTAssertTrue(
            closeSit.contains("standStartMs = now"),
            "closeSit must set standStartMs to the stop time"
        )
        let persist = try sliceFunction(tap, named: "private func persist()")
        XCTAssertTrue(
            persist.contains("standStartMs: standStartMs"),
            "persist must write standStartMs"
        )
        let persisted = try sliceFunction(tap, named: "private struct Persisted")
        XCTAssertTrue(
            persisted.contains("var standStartMs: Double?"),
            "Persisted must include standStartMs"
        )
        let load = try sliceFunction(tap, named: "private func loadPersisted()")
        XCTAssertTrue(
            load.contains("standStartMs = st.standStartMs"),
            "loadPersisted must restore standStartMs"
        )
    }

    func testContentStateHasBlock() {
        XCTAssertFalse(
            RunningBlockAttributes.ContentState().hasBlock,
            "empty state has no block"
        )
        XCTAssertFalse(
            RunningBlockAttributes.ContentState(key: "Deep work").hasBlock,
            "key without startMs has no block"
        )
        XCTAssertFalse(
            RunningBlockAttributes.ContentState(startMs: 1).hasBlock,
            "startMs without key has no block"
        )
        XCTAssertTrue(
            RunningBlockAttributes.ContentState(key: "Deep work", startMs: 1).hasBlock,
            "hasBlock is startMs != nil && key != nil"
        )
    }

    func testSitTimerRangeNilWhenNotSitting() {
        let sit = RunningBlockAttributes.ContentState(
            sitting: true, sitStartMs: 1_700_000_000_000
        )
        XCTAssertNotNil(sit.sitTimerRange, "sitting must expose sitTimerRange")
        let stand = RunningBlockAttributes.ContentState(
            sitting: false, sitStartMs: 1_700_000_000_000, standStartMs: 1_700_000_060_000
        )
        XCTAssertNil(stand.sitTimerRange, "sitTimerRange is nil when not sitting")
    }

    func testPostureTimerRangeUsesSitOrStandStart() {
        let sitMs: Double = 1_700_000_000_000
        let standMs: Double = 1_700_000_060_000
        let sit = RunningBlockAttributes.ContentState(
            sitting: true, sitStartMs: sitMs, standStartMs: standMs
        )
        XCTAssertEqual(
            sit.postureTimerRange?.lowerBound.timeIntervalSince1970,
            sitMs / 1000,
            "sitting posture timer uses sitStartMs"
        )
        let stand = RunningBlockAttributes.ContentState(
            sitting: false, sitStartMs: sitMs, standStartMs: standMs
        )
        XCTAssertEqual(
            stand.postureTimerRange?.lowerBound.timeIntervalSince1970,
            standMs / 1000,
            "standing posture timer uses standStartMs"
        )
        XCTAssertNil(
            RunningBlockAttributes.ContentState(sitting: false).postureTimerRange,
            "standing without standStartMs has no posture timer"
        )
    }

    func testContentStateDecoderDefaultsSittingFalse() throws {
        let missing = try JSONDecoder().decode(
            RunningBlockAttributes.ContentState.self,
            from: Data(#"{"key":"Deep work","startMs":1700000000000}"#.utf8)
        )
        XCTAssertFalse(missing.sitting, "sitting defaults false if missing")
        XCTAssertEqual(missing.key, "Deep work")
        XCTAssertEqual(missing.startMs, 1_700_000_000_000)
        let empty = try JSONDecoder().decode(
            RunningBlockAttributes.ContentState.self,
            from: Data(#"{}"#.utf8)
        )
        XCTAssertFalse(empty.sitting, "empty payload sitting defaults false")
    }

    func testStopSitNilsSitAndSetsStandStartMs() {
        clearPersisted()
        pinSession()
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.toggleSit()
        XCTAssertNotNil(store.sit, "toggleSit must open sit")
        now += 1_000
        store.stopSit()
        XCTAssertNil(store.sit, "stopSit must clear sit")
        XCTAssertEqual(
            store.standStartMs,
            now,
            "closeSit must set standStartMs to the stop time"
        )
        let again = TapStore()
        XCTAssertNil(again.sit, "persisted sit must stay nil after stop")
        XCTAssertEqual(
            again.standStartMs,
            now,
            "Persisted must restore standStartMs"
        )
    }

    func testEndDayLeavesSittingRunning() {
        clearPersisted()
        pinSession()
        var now: Double = 1_700_000_000_000
        let store = TapStore()
        store.clock = { now }
        store.tapCategory("Deep work")
        now += 1_000
        store.toggleSit()
        now += 60_000
        store.endDay()
        XCTAssertNil(store.open, "endDay closes the running block")
        XCTAssertNotNil(store.sit, "endDay must not nil sit")
    }

    private func pinSession() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "t"
        Credentials.planId = "p1"
        Credentials.actualId = "a1"
        Credentials.sittingId = "s1"
    }

    private func clearPersisted() {
        for key in ["tt.queue.v1", "tt.state.v1", "tt.dead.v1", "tt.blocks.v1"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
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

    private func sliceFunction(
        _ source: String,
        named marker: String,
        includingDoc: Bool = false
    ) throws -> String {
        let start = try XCTUnwrap(source.range(of: marker), "missing \(marker)")
        var from = start.lowerBound
        if includingDoc, let doc = source[..<from].range(of: "///", options: .backwards) {
            from = doc.lowerBound
        }
        let brace = try XCTUnwrap(source[from...].firstIndex(of: "{"), "no body for \(marker)")
        var depth = 0
        var i = brace
        while i < source.endIndex {
            switch source[i] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(source[from...i])
                }
            default:
                break
            }
            i = source.index(after: i)
        }
        XCTFail("unclosed \(marker)")
        return ""
    }

    private func range(_ source: String, _ needle: String) throws -> Range<String.Index> {
        try XCTUnwrap(source.range(of: needle), "missing \(needle)")
    }
}
