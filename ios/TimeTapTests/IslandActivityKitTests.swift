import XCTest
@testable import TimeTap

private struct FakeRequestError: Error {}

private final class FakeLiveActivityRuntime: LiveActivityRuntime, @unchecked Sendable {
    enum Call: Equatable {
        case update(id: String, state: RunningBlockAttributes.ContentState)
        case end(id: String)
        case request(RunningBlockAttributes.ContentState)
    }

    var areEnabled = true
    var activities: [(id: String, state: LiveActivityRunState)] = []
    var requestThrowCount = 0
    var calls: [Call] = []

    func currentActivities() -> [(id: String, state: LiveActivityRunState)] {
        activities
    }

    func update(id: String, state: RunningBlockAttributes.ContentState) async {
        calls.append(.update(id: id, state: state))
    }

    func end(id: String) async {
        calls.append(.end(id: id))
    }

    func request(_ state: RunningBlockAttributes.ContentState) async throws {
        calls.append(.request(state))
        if requestThrowCount > 0 {
            requestThrowCount -= 1
            throw FakeRequestError()
        }
    }
}

@MainActor
final class IslandActivityKitTests: TimeTapTestCase {
    private var fake = FakeLiveActivityRuntime()
    private let state = RunningBlockAttributes.ContentState(
        key: "DW",
        face: "Deep work",
        hex: "#4185F4",
        startMs: 1_700_000_000_000,
        sitting: false,
        standStartMs: 1_700_000_000_000
    )

    override func setUp() {
        super.setUp()
        fake = FakeLiveActivityRuntime()
        RunningBlockSync.runtime = fake
    }

    override func tearDown() {
        RunningBlockSync.runtime = ActivityKitLiveActivityRuntime()
        super.tearDown()
    }

    func testDisabledSkipsUpdateRequestAndEnd() async {
        fake.areEnabled = false
        fake.activities = [("keep", .active), ("extra", .active)]
        await RunningBlockSync.apply(state)
        XCTAssertEqual(fake.calls, [], "disabled must not update, request, or end")
        await RunningBlockSync.apply(nil)
        XCTAssertEqual(fake.calls, [], "disabled nil state must not end")
    }

    func testNilStateEndsEveryActivityAndDoesNotRequest() async {
        fake.activities = [("one", .active), ("two", .stale)]
        await RunningBlockSync.apply(nil)
        XCTAssertEqual(
            fake.calls,
            [.end(id: "one"), .end(id: "two")],
            "nil state must end every activity"
        )
        XCTAssertFalse(
            fake.calls.contains { if case .request = $0 { return true } else { return false } },
            "nil state must not request"
        )
    }

    func testActiveUpdatesFirstAndEndsExtras() async {
        fake.activities = [("keep", .active), ("extra-1", .active), ("extra-2", .stale)]
        await RunningBlockSync.apply(state)
        XCTAssertEqual(
            fake.calls,
            [
                .update(id: "keep", state: state),
                .end(id: "extra-1"),
                .end(id: "extra-2"),
            ],
            "active first must update then end extras"
        )
        XCTAssertFalse(
            fake.calls.contains { if case .request = $0 { return true } else { return false } },
            "active path must not request"
        )
    }

    func testStaleUpdatesAndDoesNotRequest() async {
        fake.activities = [("stale-1", .stale)]
        await RunningBlockSync.apply(state)
        XCTAssertEqual(
            fake.calls,
            [.update(id: "stale-1", state: state)],
            "stale must update"
        )
        XCTAssertFalse(
            fake.calls.contains { if case .request = $0 { return true } else { return false } },
            "stale path must not request"
        )
    }

    func testEndedDismissedOrEmptyEndsLeftoversThenRequests() async {
        fake.activities = [("dead", .ended)]
        await RunningBlockSync.apply(state)
        XCTAssertEqual(
            fake.calls,
            [.end(id: "dead"), .request(state)],
            "ended leftover must end then request"
        )

        fake.calls = []
        fake.activities = [("gone", .dismissed)]
        await RunningBlockSync.apply(state)
        XCTAssertEqual(
            fake.calls,
            [.end(id: "gone"), .request(state)],
            "dismissed leftover must end then request"
        )

        fake.calls = []
        fake.activities = []
        await RunningBlockSync.apply(state)
        XCTAssertEqual(
            fake.calls,
            [.request(state)],
            "empty list must request and not end"
        )
    }

    func testRequestRetriesOnceAfterThrow() async {
        fake.requestThrowCount = 1
        await RunningBlockSync.apply(state)
        XCTAssertEqual(
            fake.calls,
            [.request(state), .request(state)],
            "request must catch and retry once"
        )
    }

    func testRefreshOnReturnNowReappliesKilledLiveActivity() throws {
        let tap = try readIOS("TimeTap/Services/TapStore.swift")
        let refresh = try sliceFunction(tap, named: "func refreshOnReturnNow()")
        XCTAssertTrue(
            refresh.contains("defer { syncLiveActivity() }"),
            "return to the app must call syncLiveActivity so apply can restore a killed Live Activity"
        )
        let sync = try sliceFunction(tap, named: "private func syncLiveActivity()")
        XCTAssertTrue(
            sync.contains("RunningBlockSync.apply"),
            "syncLiveActivity must call RunningBlockSync.apply"
        )
        XCTAssertTrue(
            sync.contains("NSClassFromString(\"XCTestCase\") == nil"),
            "TapStore must still skip apply under XCTest"
        )
        let applyFile = try readIOS("TimeTap/LiveActivity/RunningBlockSync.swift")
        XCTAssertTrue(
            applyFile.contains("staleDate: nil"),
            "we do not mark our own 8h stale; Apple kills; apply on return restores"
        )
        XCTAssertTrue(
            applyFile.contains("pushType: nil"),
            "request must not use a push type"
        )
        XCTAssertTrue(
            applyFile.contains("ActivityKitLiveActivityRuntime"),
            "production apply uses the ActivityKit adapter"
        )
        XCTAssertTrue(
            applyFile.contains("Activity.request"),
            "the ActivityKit adapter still calls Activity.request"
        )
        XCTAssertTrue(
            applyFile.contains("ActivityAuthorizationInfo().areActivitiesEnabled"),
            "the ActivityKit adapter still reads areActivitiesEnabled"
        )
        XCTAssertTrue(
            applyFile.contains("dismissalPolicy: .immediate"),
            "the ActivityKit adapter still ends immediately"
        )
        XCTAssertTrue(
            applyFile.contains("await current.update(content)"),
            "the ActivityKit adapter still updates ActivityKit content"
        )
        XCTAssertTrue(
            applyFile.contains("attributes: RunningBlockAttributes()"),
            "the ActivityKit adapter still requests RunningBlockAttributes"
        )
        XCTAssertTrue(
            applyFile.contains("await apply(state, runtime: runtime)"),
            "production apply uses the injected runtime, ActivityKit by default"
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

    private func sliceFunction(_ source: String, named marker: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: marker), "missing \(marker)")
        let brace = try XCTUnwrap(source[start.lowerBound...].firstIndex(of: "{"), "no body for \(marker)")
        var depth = 0
        var i = brace
        while i < source.endIndex {
            switch source[i] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(source[start.lowerBound...i])
                }
            default:
                break
            }
            i = source.index(after: i)
        }
        XCTFail("unclosed \(marker)")
        return ""
    }
}
