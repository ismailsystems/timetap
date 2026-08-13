import XCTest
@testable import TimeTap

final class D2Tests: XCTestCase {
    func testReadmeHasPath3SetupSentences() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("README.md"),
            encoding: .utf8
        )
        for needle in [
            "iOS OAuth client",
            "URL scheme",
            "Google Sign-In",
            "calendar picker",
            "last-write-wins",
            "rollup stays on Apps Script",
        ] {
            XCTAssertTrue(text.contains(needle), "ios/README.md missing \(needle)")
        }
        XCTAssertFalse(
            text.contains("paste") && text.contains("API_TOKEN"),
            "setup still tells the reader to paste API_TOKEN"
        )
        XCTAssertFalse(
            text.range(of: #"paste[\s\S]{0,80}/exec"# , options: .regularExpression) != nil,
            "setup still tells the reader to paste an /exec URL"
        )
    }
}
