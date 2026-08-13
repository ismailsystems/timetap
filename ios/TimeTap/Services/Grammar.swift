import Foundation

enum TT {
    static let marks = "+=-?"
    static let minMarkMinutes = 15
    static let mistapSeconds = 20
    static let staleOpenHours = 5
    static let undoSeconds = 5
    static let maxCategories = 10
    static let maxOpTries = 5
    static let confirmTimeoutMs = 4000
    static let markTimeoutMs = 6000
    static let longBlockMinutes = 90
    static let openToken = "#open"
    static let refPrefix = "#ref:"
    static let unloggedTitle = "UNLOGGED -"
    static let unfiledKey = "UNFILED"
    static let sitTitle = "SIT"
    static let colorHex: [String: String] = [
        "1": "#7986cb", "2": "#33b679", "3": "#8e24aa", "4": "#e67c73",
        "5": "#f6bf26", "6": "#f4511e", "7": "#039be5", "8": "#616161",
        "9": "#3f51b5", "10": "#0b8043", "11": "#d50000"
    ]
    static let colorIdByKey: [String: String] = [
        "DW": "9", "MTG": "3", "ADM": "8", "BODY": "10", "REL": "6", "FRAG": "4", "POOP": "1"
    ]
}

struct ParsedTitle: Equatable {
    var key: String
    var text: String
    var mark: String?
}

enum Grammar {
    /// Vacuity: change to `[+=\\-]` and `?` parse tests go red.
    private static let markTailPattern = "(?:^|\\s)([+=\\-?])$"

    static func isMark(_ m: String?) -> Bool {
        guard let m, m.count == 1 else { return false }
        return TT.marks.contains(m)
    }

    static func buildTitle(_ key: String, _ text: String?, _ mark: String?) -> String {
        var t = key.uppercased() + ":"
        var s = String(text ?? "")
            .replacingOccurrences(of: #"[\r\n]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !isMark(mark) {
            while match(markTailPattern, s) != nil {
                s = String(s.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if key.uppercased() == "UNLOGGED" && s.isEmpty {
            return "UNLOGGED" + (isMark(mark) ? " \(mark!)" : "")
        }
        if !s.isEmpty { t += " " + s }
        if isMark(mark) { t += " \(mark!)" }
        return t
    }

    static func parseTitle(_ title: String?) -> ParsedTitle? {
        let raw = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let key: String
        var rest: String
        if let m = match("^([A-Za-z0-9_]+)\\s*:\\s*([\\s\\S]*)$", raw) {
            key = m[1].uppercased()
            rest = m[2].trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let u = match("^UNLOGGED\\b([\\s\\S]*)$", raw) {
            key = "UNLOGGED"
            rest = u[1].trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return nil
        }
        var mark: String?
        if let mm = match(markTailPattern, rest) {
            mark = mm[1]
            rest = String(rest.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ParsedTitle(key: key, text: rest, mark: mark)
    }

    static func writeDesc(_ description: String, ref: String, isOpen: Bool) -> String {
        var d = description
        d = d.replacingOccurrences(
            of: NSRegularExpression.escapedPattern(for: TT.refPrefix) + "[A-Za-z0-9]*",
            with: "",
            options: .regularExpression
        )
        d = d.replacingOccurrences(
            of: NSRegularExpression.escapedPattern(for: TT.openToken),
            with: "",
            options: .regularExpression
        )
        d = d.replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
        d = d.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        d = d.trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = TT.refPrefix + ref + (isOpen ? "\n" + TT.openToken : "")
        return d.isEmpty ? tail : d + "\n" + tail
    }

    static func colorId(for key: String) -> String {
        TT.colorIdByKey[key] ?? ""
    }

    static func hex(for key: String) -> String {
        TT.colorHex[colorId(for: key)] ?? "#616161"
    }

    static func keyFor(_ label: String, taken: [Category]) -> String {
        let stripped = label.uppercased().replacingOccurrences(
            of: "[^A-Z0-9]", with: "", options: .regularExpression
        )
        let base = String(stripped.prefix(8))
        let baseKey = base.isEmpty ? "CAT" : base
        var used = Set(taken.map(\.key))
        used.insert("UNLOGGED")
        used.insert(TT.unfiledKey)
        var key = baseKey
        var n = 2
        while used.contains(key) {
            key = String(baseKey.prefix(7)) + "\(n)"
            n += 1
        }
        return key
    }

    static func nextColor(_ taken: [Category]) -> String {
        let used = Set(taken.map(\.color))
        for id in 1...11 {
            if !used.contains(String(id)) { return String(id) }
        }
        return String((taken.count % 11) + 1)
    }

    static func match(_ pattern: String, _ s: String) -> [String]? {
        let re = try! NSRegularExpression(pattern: pattern)
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }
}
