import Foundation

struct Category: Codable, Identifiable, Hashable {
    var label: String
    var color: String
    var hex: String
    var autoMark: String?

    var id: String { label }
    var face: String { label }

    init(label: String, color: String, hex: String, autoMark: String? = nil) {
        self.label = label
        self.color = color
        self.hex = hex
        self.autoMark = autoMark
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let label = try c.decodeIfPresent(String.self, forKey: .label), !label.isEmpty {
            self.label = Grammar.resolve(label)
        } else if let key = try c.decodeIfPresent(String.self, forKey: .key), !key.isEmpty {
            self.label = Grammar.resolve(key)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .label, in: c, debugDescription: "category needs a label"
            )
        }
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? ""
        hex = try c.decodeIfPresent(String.self, forKey: .hex) ?? "#616161"
        autoMark = try c.decodeIfPresent(String.self, forKey: .autoMark)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(label, forKey: .label)
        try c.encode(color, forKey: .color)
        try c.encode(hex, forKey: .hex)
        try c.encodeIfPresent(autoMark, forKey: .autoMark)
    }

    private enum CodingKeys: String, CodingKey {
        case key, label, color, hex, autoMark
    }
}

struct CategoryGroup: Codable, Identifiable, Hashable {
    var label: String
    var color: String
    var hex: String
    var autoMark: String?
    var children: [Category]

    var id: String { label }
}

struct ClientConfig: Codable {
    var groups: [CategoryGroup]
    var retired: [String]
    var minMarkMinutes: Int
    var confirmTimeoutMs: Int
    var staleOpenHours: Int
    var markTimeoutMs: Int
    var undoSeconds: Int
    var longBlockMinutes: Int
    var maxCategories: Int
    var maxGroups: Int
    var maxOpTries: Int
    var tz: String

    var categories: [Category] { groups.flatMap(\.children) }

    static let seed: ClientConfig = {
        func leaf(_ label: String, color: String, autoMark: String? = nil) -> Category {
            Category(
                label: label, color: color,
                hex: TT.colorHex[color] ?? "#616161", autoMark: autoMark
            )
        }
        func group(
            _ label: String, color: String, autoMark: String? = nil,
            _ children: [Category]
        ) -> CategoryGroup {
            CategoryGroup(
                label: label, color: color,
                hex: TT.colorHex[color] ?? "#616161",
                autoMark: autoMark, children: children
            )
        }
        let body = ["Zone 2", "Lifting", "Walking"].map { leaf($0, color: "10", autoMark: "+") }
        return ClientConfig(
            groups: [
                group("Deep work", color: "9", [leaf("Deep work", color: "9")]),
                group("Meetings", color: "3", [leaf("Meetings", color: "3")]),
                group("Admin", color: "8", [leaf("Admin", color: "8")]),
                group("Body", color: "10", autoMark: "+", body),
                group("People", color: "6", [leaf("People", color: "6")]),
                group("Fragments", color: "4", autoMark: "-", [leaf("Fragments", color: "4", autoMark: "-")]),
                group("Poop", color: "5", [leaf("Poop", color: "5")]),
            ],
            retired: ["Body"],
            minMarkMinutes: 15,
            confirmTimeoutMs: 4000,
            staleOpenHours: 5,
            markTimeoutMs: 6000,
            undoSeconds: 5,
            longBlockMinutes: 90,
            maxCategories: 16,
            maxGroups: 8,
            maxOpTries: 5,
            tz: TimeZone.current.identifier
        )
    }()

    init(
        groups: [CategoryGroup], retired: [String] = [],
        minMarkMinutes: Int, confirmTimeoutMs: Int, staleOpenHours: Int,
        markTimeoutMs: Int, undoSeconds: Int, longBlockMinutes: Int,
        maxCategories: Int, maxGroups: Int = 8, maxOpTries: Int, tz: String
    ) {
        self.groups = groups
        self.retired = retired
        self.minMarkMinutes = minMarkMinutes
        self.confirmTimeoutMs = confirmTimeoutMs
        self.staleOpenHours = staleOpenHours
        self.markTimeoutMs = markTimeoutMs
        self.undoSeconds = undoSeconds
        self.longBlockMinutes = longBlockMinutes
        self.maxCategories = maxCategories
        self.maxGroups = maxGroups
        self.maxOpTries = maxOpTries
        self.tz = tz
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let groups = try c.decodeIfPresent([CategoryGroup].self, forKey: .groups), !groups.isEmpty {
            self.groups = groups
        } else {
            let cats = try c.decodeIfPresent([Category].self, forKey: .categories) ?? []
            self.groups = cats.map {
                CategoryGroup(
                    label: $0.label, color: $0.color, hex: $0.hex,
                    autoMark: $0.autoMark, children: [$0]
                )
            }
        }
        retired = try c.decodeIfPresent([String].self, forKey: .retired) ?? []
        minMarkMinutes = try c.decodeIfPresent(Int.self, forKey: .minMarkMinutes) ?? 15
        confirmTimeoutMs = try c.decodeIfPresent(Int.self, forKey: .confirmTimeoutMs) ?? 4000
        staleOpenHours = try c.decodeIfPresent(Int.self, forKey: .staleOpenHours) ?? 5
        markTimeoutMs = try c.decodeIfPresent(Int.self, forKey: .markTimeoutMs) ?? 6000
        undoSeconds = try c.decodeIfPresent(Int.self, forKey: .undoSeconds) ?? 5
        longBlockMinutes = try c.decodeIfPresent(Int.self, forKey: .longBlockMinutes) ?? 90
        maxCategories = try c.decodeIfPresent(Int.self, forKey: .maxCategories) ?? 16
        maxGroups = try c.decodeIfPresent(Int.self, forKey: .maxGroups) ?? 8
        maxOpTries = try c.decodeIfPresent(Int.self, forKey: .maxOpTries) ?? 5
        tz = try c.decodeIfPresent(String.self, forKey: .tz) ?? TimeZone.current.identifier
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(groups, forKey: .groups)
        try c.encode(retired, forKey: .retired)
        try c.encode(minMarkMinutes, forKey: .minMarkMinutes)
        try c.encode(confirmTimeoutMs, forKey: .confirmTimeoutMs)
        try c.encode(staleOpenHours, forKey: .staleOpenHours)
        try c.encode(markTimeoutMs, forKey: .markTimeoutMs)
        try c.encode(undoSeconds, forKey: .undoSeconds)
        try c.encode(longBlockMinutes, forKey: .longBlockMinutes)
        try c.encode(maxCategories, forKey: .maxCategories)
        try c.encode(maxGroups, forKey: .maxGroups)
        try c.encode(maxOpTries, forKey: .maxOpTries)
        try c.encode(tz, forKey: .tz)
    }

    private enum CodingKeys: String, CodingKey {
        case groups, categories, retired
        case minMarkMinutes, confirmTimeoutMs, staleOpenHours
        case markTimeoutMs, undoSeconds, longBlockMinutes
        case maxCategories, maxGroups, maxOpTries, tz
    }
}

struct OpenBlock: Codable, Equatable {
    var ref: String
    var key: String
    var text: String
    var startMs: Double

    init(ref: String, key: String, text: String = "", startMs: Double) {
        self.ref = ref
        self.key = Grammar.resolve(key)
        self.text = text
        self.startMs = startMs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ref = try c.decode(String.self, forKey: .ref)
        key = Grammar.resolve(try c.decode(String.self, forKey: .key))
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

    init(ref: String? = nil, key: String, startMs: Double, endMs: Double, text: String = "") {
        self.ref = ref
        self.key = Grammar.resolve(key)
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ref = try c.decodeIfPresent(String.self, forKey: .ref)
        key = Grammar.resolve(try c.decode(String.self, forKey: .key))
        startMs = try c.decode(Double.self, forKey: .startMs)
        endMs = try c.decode(Double.self, forKey: .endMs)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
    }
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
