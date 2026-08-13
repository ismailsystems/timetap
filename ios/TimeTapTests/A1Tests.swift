import XCTest
@testable import TimeTap

final class A1Tests: TimeTapTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
    }

    func testInfoPlistHasGoogleClientAndURLScheme() {
        let bundle = Bundle(for: TapStore.self)
        let clientID = bundle.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
        XCTAssertTrue(
            clientID.contains("apps.googleusercontent.com"),
            "GIDClientID missing or not a Google iOS client: \(clientID)"
        )
        let types = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = types.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
        XCTAssertTrue(
            schemes.contains { $0.hasPrefix("com.googleusercontent.apps.") },
            "Google URL scheme missing: \(schemes)"
        )
    }

    func testSettingsAndCredentialsHaveNoTokenForm() throws {
        let ios = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settings = try String(
            contentsOf: ios.appendingPathComponent("TimeTap/Views/SettingsView.swift"),
            encoding: .utf8
        )
        let creds = try String(
            contentsOf: ios.appendingPathComponent("TimeTap/Services/Credentials.swift"),
            encoding: .utf8
        )
        for (name, text) in [("SettingsView.swift", settings), ("Credentials.swift", creds)] {
            XCTAssertFalse(text.contains("API_TOKEN"), "\(name) still mentions API_TOKEN")
            XCTAssertFalse(text.contains("/exec"), "\(name) still has an /exec URL field")
            XCTAssertFalse(text.contains("TimetapAPI"), "\(name) still calls TimetapAPI")
        }
    }

    func testNotConfiguredDoesNotEnqueueOpenActual() async {
        await MainActor.run {
            Credentials.resetForTests()
            XCTAssertFalse(Credentials.isConfigured)
            let store = TapStore()
            let before = store.queue.filter { $0.type == "openActual" }.count
            store.tapCategory("DW")
            let after = store.queue.filter { $0.type == "openActual" }.count
            XCTAssertEqual(before, after)
            XCTAssertTrue(store.showSignIn)
        }
    }

    func testCancelledSignInStoresNothingAndDoesNotTalkToCalendar() {
        GoogleAuth.testHasSession = true
        GoogleAuth.testAccessToken = "fake-token"
        GoogleAuth.didFetchCalendarList = true
        GoogleAuth.didAttemptCalendarWrite = true
        GoogleAuth.applyCancelledSignIn()
        XCTAssertFalse(GoogleAuth.hasSession)
        XCTAssertNil(GoogleAuth.accessToken)
        XCTAssertTrue(GoogleAuth.lastSignInCancelled)
        XCTAssertFalse(GoogleAuth.didFetchCalendarList)
        XCTAssertFalse(GoogleAuth.didAttemptCalendarWrite)
    }
}
