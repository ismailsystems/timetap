import XCTest
@testable import TimeTap

final class WatchContractTests: TimeTapTestCase {
    func testWatchStateRoundtrips() throws {
        let state = WatchState(
            openKey: "Deep work",
            openFace: "Deep work",
            openHex: "#3f51b5",
            startMs: 1_700_000_000_000,
            distracted: true,
            distractedMs: 120_000,
            groups: [
                WatchGroup(
                    label: "Work",
                    hex: "#3f51b5",
                    children: [WatchChild(label: "Deep work", hex: "#3f51b5")]
                )
            ]
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(WatchState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testWatchCommandProposeToggleDistractAndEndDayRoundtrip() throws {
        let commands: [WatchCommand] = [
            .propose(key: "Deep work"),
            .toggleDistract,
            .endDay
        ]
        for cmd in commands {
            let data = try JSONEncoder().encode(cmd)
            let decoded = try JSONDecoder().decode(WatchCommand.self, from: data)
            XCTAssertEqual(decoded, cmd)
        }
    }

    func testWatchCaptureViewTogglesDistractWithoutPropose() throws {
        let text = try iosSource("TimeTapWatch/WatchCaptureView.swift")
        XCTAssertTrue(text.contains("\"Distracted\""), "watch face names Distracted")
        XCTAssertTrue(text.contains("toggleDistract"), "watch sends toggleDistract")
        let start = try XCTUnwrap(
            text.range(of: "session.send(.toggleDistract)"),
            "Distracted must send toggleDistract"
        )
        let stop = try XCTUnwrap(
            text.range(of: "session.send(.endDay)"),
            "Stop must send endDay"
        )
        XCTAssertLessThan(start.lowerBound, stop.lowerBound)
        let distract = text[start.lowerBound..<stop.lowerBound]
        XCTAssertTrue(distract.contains("Distracted"))
        XCTAssertFalse(
            distract.contains("propose"),
            "toggling distract must not propose a category"
        )
    }

    func testProjectYmlHasWatchApp() throws {
        let yml = try iosSource("project.yml")
        XCTAssertTrue(yml.contains("TimeTapWatch"), "project.yml must name the watch app")
        XCTAssertTrue(yml.contains("watchkitapp"), "watch bundle id must stay a watchkitapp")
    }

    private func iosSource(_ relative: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(relative),
            encoding: .utf8
        )
    }
}
