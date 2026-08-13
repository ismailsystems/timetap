import ActivityKit
import Foundation

struct RunningBlockAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var key: String?
        var face: String?
        var hex: String?
        var startMs: Double?
        var sitting: Bool
        var sitStartMs: Double?
        var standStartMs: Double?

        init(
            key: String? = nil,
            face: String? = nil,
            hex: String? = nil,
            startMs: Double? = nil,
            sitting: Bool = false,
            sitStartMs: Double? = nil,
            standStartMs: Double? = nil
        ) {
            self.key = key
            self.face = face
            self.hex = hex
            self.startMs = startMs
            self.sitting = sitting
            self.sitStartMs = sitStartMs
            self.standStartMs = standStartMs
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            key = try c.decodeIfPresent(String.self, forKey: .key)
            face = try c.decodeIfPresent(String.self, forKey: .face)
            hex = try c.decodeIfPresent(String.self, forKey: .hex)
            startMs = try c.decodeIfPresent(Double.self, forKey: .startMs)
            sitting = try c.decodeIfPresent(Bool.self, forKey: .sitting) ?? false
            sitStartMs = try c.decodeIfPresent(Double.self, forKey: .sitStartMs)
            standStartMs = try c.decodeIfPresent(Double.self, forKey: .standStartMs)
        }

        var hasBlock: Bool { startMs != nil && key != nil }

        var timerRange: ClosedRange<Date>? {
            Self.range(from: startMs)
        }

        var sitTimerRange: ClosedRange<Date>? {
            guard sitting else { return nil }
            return Self.range(from: sitStartMs)
        }

        var postureTimerRange: ClosedRange<Date>? {
            sitting ? Self.range(from: sitStartMs) : Self.range(from: standStartMs)
        }

        private static func range(from startMs: Double?) -> ClosedRange<Date>? {
            guard let startMs else { return nil }
            let start = Date(timeIntervalSince1970: startMs / 1000)
            return start...(start.addingTimeInterval(12 * 3600))
        }
    }
}
