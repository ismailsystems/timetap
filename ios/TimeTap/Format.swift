import Foundation

enum Format {
    private static let msMin: Double = 60_000

    static func clock(_ ms: Double) -> String {
        let d = Date(timeIntervalSince1970: ms / 1000)
        let cal = calendar()
        var h = cal.component(.hour, from: d)
        let m = cal.component(.minute, from: d)
        let am = h < 12
        h = h % 12
        if h == 0 { h = 12 }
        return "\(h):\(String(format: "%02d", m))\(am ? " AM" : " PM")"
    }

    static func elapsed(_ ms: Double) -> String {
        let m = Int(max(0, ms) / msMin)
        let h = m / 60
        if h > 0 { return "\(h)h" + String(format: "%02d", m % 60) }
        return "\(m)m"
    }

    static func duration(_ ms: Double) -> String {
        let m = max(0, Int((ms / msMin).rounded()))
        let h = m / 60
        if h > 0 { return "\(h)h \(m % 60)m" }
        return "\(m)m"
    }

    static func shortElapsed(_ ms: Double) -> String {
        if ms < msMin { return "<1m" }
        return elapsed(ms)
    }

    static func dayStartMs(_ ms: Double) -> Double {
        let d = Date(timeIntervalSince1970: ms / 1000)
        return calendar().startOfDay(for: d).timeIntervalSince1970 * 1000
    }

    private static func calendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = ApplyOps.timeZone
        return cal
    }

    static let opWords: [String: String] = [
        "openActual": "start a block",
        "closeActual": "close a block",
        "recategorize": "change the category",
        "setMark": "save the mark",
        "setText": "save the note",
        "splitActual": "split a block",
        "openSit": "start sitting",
        "closeSit": "stop sitting",
        "setSitStart": "correct when sitting started",
        "deleteSit": "remove a sitting block",
        "undoSwitch": "take back a switch"
    ]
}
