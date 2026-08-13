import Foundation

struct Category: Codable, Identifiable, Hashable {
    var key: String
    var label: String
    var color: String
    var hex: String
    var autoMark: String?

    var id: String { key }
    var face: String { label.isEmpty ? key : label }
}

struct ClientConfig: Codable {
    var categories: [Category]
    var minMarkMinutes: Int
    var confirmTimeoutMs: Int
    var staleOpenHours: Int
    var markTimeoutMs: Int
    var undoSeconds: Int
    var longBlockMinutes: Int
    var maxCategories: Int
    var maxOpTries: Int
    var tz: String

    /// Code.gs CATEGORIES plus POOP. POOP is banana yellow (id 5), not lavender 1 (DW's hue).
    static let seed = ClientConfig(
        categories: [
            Category(key: "DW", label: "Deep work", color: "9", hex: "#3f51b5", autoMark: nil),
            Category(key: "MTG", label: "Meetings", color: "3", hex: "#8e24aa", autoMark: nil),
            Category(key: "ADM", label: "Admin", color: "8", hex: "#616161", autoMark: nil),
            Category(key: "BODY", label: "Body", color: "10", hex: "#0b8043", autoMark: "+"),
            Category(key: "REL", label: "People", color: "6", hex: "#f4511e", autoMark: nil),
            Category(key: "FRAG", label: "Fragments", color: "4", hex: "#e67c73", autoMark: "-"),
            Category(key: "POOP", label: "Poop", color: "5", hex: "#f6bf26", autoMark: nil),
        ],
        minMarkMinutes: 15,
        confirmTimeoutMs: 4000,
        staleOpenHours: 5,
        markTimeoutMs: 6000,
        undoSeconds: 5,
        longBlockMinutes: 90,
        maxCategories: 10,
        maxOpTries: 5,
        tz: TimeZone.current.identifier
    )
}

struct OpenBlock: Codable, Equatable {
    var ref: String
    var key: String
    var text: String
    var startMs: Double

    init(ref: String, key: String, text: String = "", startMs: Double) {
        self.ref = ref
        self.key = key
        self.text = text
        self.startMs = startMs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ref = try c.decode(String.self, forKey: .ref)
        key = try c.decode(String.self, forKey: .key)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        startMs = try c.decode(Double.self, forKey: .startMs)
    }
}

struct SitBlock: Codable, Equatable {
    var ref: String
    var startMs: Double
}

struct TodayBlock: Codable, Equatable {
    var ref: String? = nil
    var key: String
    var startMs: Double
    var endMs: Double
    var text: String = ""
}

struct DeadEntry: Codable, Equatable, Identifiable {
    var at: Double
    var why: String
    var op: Op
    var key: String?
    var startMs: Double?

    var id: String { token }

    var token: String {
        "\(at)|\(op.id)|\(op.type)|\(op.ref ?? "")"
    }
}

struct ServerState: Codable {
    var nowMs: Double?
    var tz: String?
    var open: OpenBlock?
    var sit: SitBlock?
    var notes: [String]?
    var today: [TodayBlock]?
}

struct ApplyResult: Codable {
    var applied: [String]?
    var errors: [ApplyError]?
    var dropped: [DroppedOp]?

    struct ApplyError: Codable {
        var id: String?
        var message: String?
    }

    struct DroppedOp: Codable {
        var id: String?
    }
}

/// One wire op. Extra fields are omitted when nil (JSONEncoder).
struct Op: Codable, Identifiable, Equatable {
    var id: String
    var type: String
    var ts: Double? = nil
    var ref: String? = nil
    var key: String? = nil
    var text: String? = nil
    var mark: String? = nil
    var startMs: Double? = nil
    var endMs: Double? = nil
    var atMs: Double? = nil
    var nowMs: Double? = nil
    var hintMs: Double? = nil
    var newRef: String? = nil
    var newKey: String? = nil
    var prevRef: String? = nil
    var prevKey: String? = nil
    var prevText: String? = nil
    var prevStartMs: Double? = nil
    var sitRef: String? = nil
    var sitStartMs: Double? = nil
    var killSitRef: String? = nil
    var tries: Int? = nil

    static func uid() -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<16).map { _ in alphabet.randomElement()! })
    }
}

struct ApiEnvelope<T: Decodable>: Decodable {
    var ok: Bool
    var result: T?
    var error: String?
}

struct ApiEmpty: Decodable {}
