import XCTest
@testable import TimeTapMac

/// File-path source locks live in TimeTapTests (iOS). Reading #filePath
/// from this Mac host hangs under the test sandbox.
final class MacChromeTests: XCTestCase {
    func testPollIntervals() {
        XCTAssertEqual(MacSync.pollNs(active: true), 15_000_000_000)
        XCTAssertEqual(MacSync.pollNs(active: false), 60_000_000_000)
    }
}
