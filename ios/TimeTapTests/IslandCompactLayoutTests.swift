import SwiftUI
import UIKit
import XCTest
@testable import TimeTap

private var islandCompactWindow: UIWindow?

@MainActor
final class IslandCompactLayoutTests: TimeTapTestCase {
    override func tearDown() {
        islandCompactWindow = nil
        super.tearDown()
    }

    func testIslandBlockCompactHeightFits37() {
        let state = RunningBlockAttributes.ContentState(
            key: "Deep work",
            face: "DEEP WORK",
            startMs: 1_700_000_000_000
        )
        XCTAssertTrue(state.hasBlock)
        let view = IslandCompact.islandBlock(state, nameSize: 10, timeSize: 12, timeWidth: 54)
            .padding(.leading, 8)
            .frame(width: 62, height: 37)
        measureHeight("islandBlock", view, width: 62, height: 37)
    }

    func testIslandPostureNotSittingCompactHeightFits37() {
        let state = RunningBlockAttributes.ContentState(
            sitting: false,
            standStartMs: 1_700_000_000_000
        )
        let view = IslandCompact.islandPosture(state, nameSize: 10, timeSize: 12, timeWidth: 54)
            .padding(.trailing, 8)
            .frame(width: 62, height: 37)
        measureHeight("islandPosture", view, width: 62, height: 37)
    }

    func testCompactLeadingAndTrailingStackFits37() {
        let state = RunningBlockAttributes.ContentState(
            key: "Deep work",
            face: "DEEP WORK",
            startMs: 1_700_000_000_000,
            sitting: false,
            standStartMs: 1_700_000_000_000
        )
        let view = HStack(spacing: 8) {
            IslandCompact.islandBlock(state, nameSize: 10, timeSize: 12, timeWidth: 54)
                .padding(.leading, 8)
            IslandCompact.islandPosture(state, nameSize: 10, timeSize: 12, timeWidth: 54)
                .padding(.trailing, 8)
        }
        .frame(width: 140, height: 37)
        measureHeight("compactStack", view, width: 140, height: 37)
    }

    func testCompactSlotsCallExtractedIslandCompact() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTapWidget/RunningBlockLiveActivity.swift"),
            encoding: .utf8
        )
        let leading = slice(text, from: "compactLeading", to: "compactTrailing")
        let trailing = slice(text, from: "compactTrailing", to: "minimal")
        XCTAssertTrue(
            leading.contains("IslandCompact.islandBlock"),
            "compact leading must call extracted IslandCompact.islandBlock"
        )
        XCTAssertFalse(
            leading.contains("\n                islandBlock("),
            "compact leading must not call a leftover private islandBlock"
        )
        XCTAssertTrue(
            trailing.contains("IslandCompact.islandPosture"),
            "compact trailing must call extracted IslandCompact.islandPosture"
        )
        XCTAssertFalse(
            trailing.contains("\n                islandPosture("),
            "compact trailing must not call a leftover private islandPosture"
        )
        XCTAssertTrue(leading.contains("timeWidth: 54"))
        XCTAssertTrue(trailing.contains("timeWidth: 54"))
        XCTAssertTrue(leading.contains(".padding(.leading, 8)"))
        XCTAssertTrue(trailing.contains(".padding(.trailing, 8)"))
        let extracted = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("TimeTap/LiveActivity/IslandCompact.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            extracted.contains("state.sitting ? \"SITTING\" : \"NOT SITTING\""),
            "compact right must name NOT SITTING when not sitting"
        )
        XCTAssertFalse(extracted.contains("STANDING"), "compact Island must not say STANDING")
        XCTAssertTrue(
            extracted.contains("Color.clear.frame(width: 1, height: 1)"),
            "empty compact leading must be a 1pt clear point"
        )
        XCTAssertTrue(extracted.contains(".clipped()"), "compact stacks must clip")
    }

    private func measureHeight<V: View>(_ name: String, _ view: V, width: CGFloat, height: CGFloat) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        host.view.layoutIfNeeded()
        islandCompactWindow = window
        XCTAssertLessThanOrEqual(host.view.bounds.height, 37.5)
        let maxH = walk(host.view)
        print("\(name) host=\(host.view.bounds.height) maxDescendant=\(maxH)")
    }

    @discardableResult
    private func walk(_ view: UIView) -> CGFloat {
        XCTAssertLessThanOrEqual(
            view.bounds.height,
            37.5,
            "descendant \(type(of: view)) height \(view.bounds.height) > 37.5"
        )
        var maxH = view.bounds.height
        for sub in view.subviews {
            maxH = max(maxH, walk(sub))
        }
        return maxH
    }

    private func slice(_ text: String, from: String, to: String) -> Substring {
        guard let a = text.range(of: from), let b = text.range(of: to), a.lowerBound < b.lowerBound else {
            XCTFail("source lost \(from) .. \(to)")
            return ""
        }
        return text[a.lowerBound..<b.lowerBound]
    }
}
