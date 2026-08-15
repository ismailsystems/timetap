import XCTest
@testable import TimeTap

@MainActor
final class C2Tests: TimeTapTestCase {
    override func setUp() {
        super.setUp()
        Credentials.resetForTests()
        CalendarAPI.resetTestHTTP()
        GoogleAuth.resetForTests()
    }

    func testFreshStoreOfflineHasSeedLeaves() {
        GoogleAuth.testHasSession = false
        let store = TapStore()
        XCTAssertEqual(
            store.categories.map(\.label),
            ["Deep work", "Meetings", "Admin", "Zone 2", "Lifting", "Walking", "People", "Fragments", "Poop"]
        )
        XCTAssertEqual(store.groups.map(\.label), [
            "Deep work", "Meetings", "Admin", "Body", "People", "Fragments", "Poop"
        ])
        XCTAssertFalse(Credentials.isConfigured)
    }

    func testAddDeepReadingIsLocalAndMakesANewGroup() {
        GoogleAuth.testHasSession = false
        let store = TapStore()
        XCTAssertEqual(store.categories.count, 9)
        CalendarAPI.didFlush = false
        GoogleAuth.didFetchCalendarList = false
        GoogleAuth.didAttemptCalendarWrite = false
        store.addCategory(label: "Deep reading")
        XCTAssertEqual(store.categories.count, 10)
        let extra = store.categories.last
        XCTAssertEqual(extra?.label, "Deep reading")
        XCTAssertEqual(extra?.color, "1")
        XCTAssertTrue(store.groups.contains { $0.label == "Deep reading" && $0.children.count == 1 })
        XCTAssertFalse(CalendarAPI.didFlush)
        XCTAssertFalse(GoogleAuth.didFetchCalendarList)
        XCTAssertFalse(GoogleAuth.didAttemptCalendarWrite)
    }

    func testNinthGroupIsRefused() {
        let store = TapStore()
        store.addCategory(label: "One")
        XCTAssertEqual(store.groups.count, 8)
        store.addCategory(label: "Two")
        XCTAssertEqual(store.groups.count, 8)
        XCTAssertEqual(store.banner, "That is 8 groups already.")
        XCTAssertFalse(store.categories.contains { $0.label == "Two" })
    }

    func testExtraSurvivesRelaunchOffline() {
        GoogleAuth.testHasSession = false
        let store = TapStore()
        store.addCategory(label: "Deep reading")
        let again = TapStore()
        XCTAssertTrue(again.categories.contains { $0.label == "Deep reading" })
        XCTAssertFalse(Credentials.isConfigured)
    }

    func testBlankLabelAddsNothing() {
        let store = TapStore()
        XCTAssertEqual(store.categories.count, 9)
        store.addCategory(label: "   ")
        XCTAssertEqual(store.categories.count, 9)
        XCTAssertEqual(store.banner, "A category needs a name.")
    }

    func testDeleteLastChildIsRefused() {
        let store = TapStore()
        store.deleteChild("Deep work")
        XCTAssertEqual(store.banner, "Delete the group instead.")
        XCTAssertTrue(store.categories.contains { $0.label == "Deep work" })
    }

    func testNeighborWrapsAndArmSetsLastUsed() {
        let store = TapStore()
        let body = store.groups.first { $0.label == "Body" }!
        XCTAssertEqual(store.neighbor(in: body, of: "Zone 2", step: 1), "Lifting")
        XCTAssertEqual(store.neighbor(in: body, of: "Walking", step: 1), "Zone 2")
        XCTAssertEqual(store.neighbor(in: body, of: "Zone 2", step: -1), "Walking")
        store.arm(body, child: "Lifting")
        XCTAssertEqual(store.pickFromGroup(body, hover: nil), "Lifting")
    }

    func testAddAndDeleteChild() {
        let store = TapStore()
        store.addChild(group: "Deep work", label: "Writing")
        XCTAssertTrue(store.categories.contains { $0.label == "Writing" })
        store.deleteChild("Writing")
        XCTAssertFalse(store.categories.contains { $0.label == "Writing" })
        XCTAssertTrue(store.config?.retired.contains("Writing") == true)
    }

    func testCodeGsListsLeavesNotGroups() throws {
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
        XCTAssertFalse(block.contains("key:"))
        XCTAssertTrue(block.contains("Zone 2"))
        XCTAssertTrue(block.contains("Fragments"))
        XCTAssertEqual(block.components(separatedBy: "label:").count - 1, 8)
    }
}
