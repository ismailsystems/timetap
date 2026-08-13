import XCTest
@testable import TimeTap

@MainActor
final class C2Tests: XCTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        CalendarAPI.resetTestHTTP()
        GoogleAuth.resetForTests()
    }

    func testFreshStoreOfflineHasSeedPlusPOOP() {
        GoogleAuth.testHasSession = false
        let store = TapStore()
        XCTAssertEqual(
            store.categories.map(\.key),
            ["DW", "MTG", "ADM", "BODY", "REL", "FRAG", "POOP"]
        )
        XCTAssertFalse(Credentials.isConfigured)
    }

    func testAddDeepReadingIsLocalAndMakesAnEighthKey() {
        GoogleAuth.testHasSession = false
        let store = TapStore()
        XCTAssertEqual(store.categories.count, 7)
        CalendarAPI.didFlush = false
        GoogleAuth.didFetchCalendarList = false
        GoogleAuth.didAttemptCalendarWrite = false
        store.addCategory(label: "Deep reading")
        XCTAssertEqual(store.categories.count, 8)
        let extra = store.categories.last
        XCTAssertEqual(extra?.key, "DEEPREAD")
        XCTAssertEqual(extra?.label, "Deep reading")
        XCTAssertEqual(extra?.color, "2")
        XCTAssertFalse(CalendarAPI.didFlush)
        XCTAssertFalse(GoogleAuth.didFetchCalendarList)
        XCTAssertFalse(GoogleAuth.didAttemptCalendarWrite)
    }

    func testEleventhAddIsRefusedWithCeiling() {
        let store = TapStore()
        store.addCategory(label: "One")
        store.addCategory(label: "Two")
        store.addCategory(label: "Three")
        XCTAssertEqual(store.categories.count, 10)
        store.addCategory(label: "Eleven")
        XCTAssertEqual(store.categories.count, 10)
        XCTAssertEqual(store.banner, "That is 10 categories already.")
        XCTAssertFalse(store.categories.contains { $0.label == "Eleven" })
    }

    func testExtraSurvivesRelaunchOffline() {
        GoogleAuth.testHasSession = false
        let store = TapStore()
        store.addCategory(label: "Deep reading")
        let again = TapStore()
        XCTAssertTrue(again.categories.contains { $0.key == "DEEPREAD" && $0.label == "Deep reading" })
        XCTAssertFalse(Credentials.isConfigured)
    }

    func testBlankLabelAddsNothing() {
        let store = TapStore()
        store.addCategory(label: "   ")
        XCTAssertEqual(store.categories.count, 7)
        XCTAssertEqual(store.banner, "A category needs a name.")
    }

    func testRemoveCategoryIsAbsent() throws {
        let ios = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TimeTap")
        var hits: [String] = []
        let walker = FileManager.default.enumerator(at: ios, includingPropertiesForKeys: nil)!
        while let url = walker.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains("removeCategory") { hits.append(url.lastPathComponent) }
        }
        XCTAssertTrue(hits.isEmpty, "removeCategory still in \(hits)")
    }

    func testCodeGsCATEGORIESUnchanged() throws {
        let gs = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Code.gs")
        let text = try String(contentsOf: gs, encoding: .utf8)
        guard let start = text.range(of: "var CATEGORIES = ["),
              let end = text[start.upperBound...].range(of: "];") else {
            XCTFail("CATEGORIES missing in Code.gs")
            return
        }
        let block = String(text[start.lowerBound..<end.upperBound])
        XCTAssertFalse(block.contains("POOP"))
        XCTAssertTrue(block.contains("DW"))
        XCTAssertTrue(block.contains("FRAG"))
        let keys = ["DW", "MTG", "ADM", "BODY", "REL", "FRAG"]
        XCTAssertEqual(keys.filter { block.contains("key: '\($0)'") || block.contains("key: \"\($0)\"") }.count, 6)
    }
}
