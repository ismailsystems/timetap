import XCTest
@testable import TimeTap

class TimeTapTestCase: XCTestCase {
    override func tearDown() {
        Credentials.resetForTests()
        ApplyOps.resetForTests()
        super.tearDown()
    }
}
