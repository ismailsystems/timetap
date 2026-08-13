import XCTest
@testable import TimeTap

final class B1Tests: XCTestCase {
    func testBuildTitleQuestionMark() {
        XCTAssertEqual(Grammar.buildTitle("DW", "memo drafting", "?"), "DW: memo drafting ?")
    }

    func testParseTitleQuestionMark() {
        let p = Grammar.parseTitle("DW: memo drafting ?")
        XCTAssertEqual(p?.key, "DW")
        XCTAssertEqual(p?.text, "memo drafting")
        XCTAssertEqual(p?.mark, "?")
    }

    func testRoundtripMatchesCodeGsGolden() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("test/fixtures/title-golden.json")
        let data = try Data(contentsOf: url)
        let golden = try JSONDecoder().decode(TitleGolden.self, from: data)
        XCTAssertEqual(golden.roundtrip.count, 35)
        for row in golden.roundtrip {
            let built = Grammar.buildTitle("DW", row.text, row.mark)
            XCTAssertEqual(built, row.built, "build \(row.text) \(row.mark ?? "null")")
            let parsed = Grammar.parseTitle(built)
            XCTAssertEqual(parsed?.key, row.parsed.key)
            XCTAssertEqual(parsed?.text, row.parsed.text)
            XCTAssertEqual(parsed?.mark, row.parsed.mark)
            let rebuilt = Grammar.buildTitle(parsed!.key, parsed!.text, parsed!.mark)
            XCTAssertEqual(rebuilt, built)
            XCTAssertEqual(rebuilt, row.rebuilt)
        }
    }

    func testUnloggedTitle() {
        XCTAssertEqual(Grammar.buildTitle("UNLOGGED", "", "-"), "UNLOGGED -")
        XCTAssertEqual(Grammar.buildTitle("UNLOGGED", "something", nil), "UNLOGGED: something")
    }

    func testWriteDescReplacesTokens() {
        let open = Grammar.writeDesc("hello", ref: "abc", isOpen: true)
        XCTAssertEqual(open, "hello\n#ref:abc\n#open")
        let closed = Grammar.writeDesc(open, ref: "abc", isOpen: false)
        XCTAssertEqual(closed, "hello\n#ref:abc")
        XCTAssertFalse(closed.contains("#open"))
        let again = Grammar.writeDesc(closed, ref: "abc", isOpen: true)
        XCTAssertEqual(again.components(separatedBy: "#ref:").count - 1, 1)
        XCTAssertEqual(again.components(separatedBy: "#open").count - 1, 1)
    }

    func testCategoryColours() {
        let want: [(String, String, String)] = [
            ("DW", "9", "#3f51b5"),
            ("MTG", "3", "#8e24aa"),
            ("ADM", "8", "#616161"),
            ("BODY", "10", "#0b8043"),
            ("REL", "6", "#f4511e"),
            ("FRAG", "4", "#e67c73"),
        ]
        for (key, id, hex) in want {
            XCTAssertEqual(Grammar.colorId(for: key), id, key)
            XCTAssertEqual(Grammar.hex(for: key), hex, key)
        }
    }

    func testPinnedConstants() {
        XCTAssertEqual(TT.minMarkMinutes, 15)
        XCTAssertEqual(TT.mistapSeconds, 20)
        XCTAssertEqual(TT.staleOpenHours, 5)
        XCTAssertEqual(TT.undoSeconds, 5)
        XCTAssertEqual(TT.maxCategories, 10)
        XCTAssertEqual(TT.maxOpTries, 5)
    }

    func testSeedHasSixPlusPOOP() throws {
        let keys = ClientConfig.seed.categories.map(\.key)
        XCTAssertEqual(keys, ["DW", "MTG", "ADM", "BODY", "REL", "FRAG", "POOP"])
        XCTAssertEqual(ClientConfig.seed.categories.first { $0.key == "POOP" }?.color, "1")
        let gs = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Code.gs"),
            encoding: .utf8
        )
        guard let start = gs.range(of: "var CATEGORIES = ["),
              let end = gs[start.upperBound...].range(of: "];") else {
            return XCTFail("CATEGORIES missing")
        }
        XCTAssertFalse(String(gs[start.lowerBound..<end.upperBound]).contains("POOP"))
    }

    func testLunchWithAdaDoesNotParse() {
        XCTAssertNil(Grammar.parseTitle("Lunch with Ada"))
    }

    func testDoubledQuestionIsTextNotMark() {
        let p = Grammar.parseTitle("DW: memo ??")
        XCTAssertEqual(p?.mark, nil)
        XCTAssertEqual(p?.text, "memo ??")
    }
}

private struct TitleGolden: Decodable {
    var roundtrip: [Row]
    struct Row: Decodable {
        var text: String
        var mark: String?
        var built: String
        var parsed: Parsed
        var rebuilt: String
    }
    struct Parsed: Decodable {
        var key: String
        var text: String
        var mark: String?
    }
}
