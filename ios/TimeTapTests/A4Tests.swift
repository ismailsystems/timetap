import XCTest
@testable import TimeTap

final class A4Tests: TimeTapTestCase {
    func testTimeTapSourcesDoNotReferenceTimetapAPI() throws {
        let ios = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TimeTap")
        var hits: [String] = []
        let walker = FileManager.default.enumerator(at: ios, includingPropertiesForKeys: nil)!
        while let url = walker.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains("TimetapAPI") {
                hits.append(url.lastPathComponent)
            }
        }
        XCTAssertTrue(hits.isEmpty, "TimetapAPI still referenced in \(hits)")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: ios.appendingPathComponent("Services/TimetapAPI.swift").path)
        )
    }

    func testSeedPutsDWOnTheGridWithPOOPColor1() async {
        await MainActor.run {
            Credentials.resetForTests()
            let store = TapStore()
            XCTAssertEqual(
                store.categories.map(\.key),
                ["DW", "MTG", "ADM", "BODY", "REL", "FRAG", "POOP"]
            )
            XCTAssertEqual(store.categories.first { $0.key == "DW" }?.color, "9")
            XCTAssertEqual(store.categories.first { $0.key == "DW" }?.hex, "#3f51b5")
            let poop = store.categories.first { $0.key == "POOP" }
            XCTAssertEqual(poop?.color, "1")
            XCTAssertEqual(poop?.hex, "#7986cb")
        }
    }

    func testPOOPIsNotInCodeGsCATEGORIES() throws {
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
        XCTAssertFalse(block.contains("POOP"), "POOP leaked into Code.gs CATEGORIES")
    }

    func testConfiguredMeansGoogleSessionPlusCalendarIds() {
        Credentials.resetForTests()
        XCTAssertFalse(Credentials.isConfigured)
        GoogleAuth.testHasSession = true
        XCTAssertFalse(Credentials.isConfigured)
        Credentials.planId = "p"
        Credentials.actualId = "a"
        Credentials.sittingId = "s"
        XCTAssertTrue(Credentials.isConfigured)
    }

    func testSecretsAPITokenIsNotRead() throws {
        let ios = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TimeTap")
        let walker = FileManager.default.enumerator(at: ios, includingPropertiesForKeys: nil)!
        while let url = walker.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.contains("API_TOKEN"), url.lastPathComponent)
            XCTAssertFalse(text.contains(".secrets"), url.lastPathComponent)
            XCTAssertFalse(text.contains("apiToken"), url.lastPathComponent)
            XCTAssertFalse(text.contains("apiURL"), url.lastPathComponent)
        }
    }
}
