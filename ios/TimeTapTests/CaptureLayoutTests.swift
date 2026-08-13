import SwiftUI
import UIKit
import XCTest
@testable import TimeTap

private var captureLayoutWindow: UIWindow?

@MainActor
final class CaptureLayoutTests: TimeTapTestCase {
    override func tearDown() {
        captureLayoutWindow = nil
        super.tearDown()
    }

    func testElapsedTimerClipsTo54() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let range = start...(start.addingTimeInterval(12 * 3600))
        let view = ElapsedTimer(range: range, size: 12, width: 54, align: .leading)
            .frame(width: 54, height: 20)
            .clipped()
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 54, height: 20))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        host.view.layoutIfNeeded()
        captureLayoutWindow = window
        XCTAssertLessThanOrEqual(host.view.bounds.width, 54)
        walk(host.view)
    }

    private func walk(_ view: UIView) {
        XCTAssertLessThanOrEqual(
            view.bounds.width,
            54.5,
            "descendant \(type(of: view)) width \(view.bounds.width) > 54"
        )
        for sub in view.subviews { walk(sub) }
    }
}
