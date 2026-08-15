import Foundation

/// Wire types for WatchConnectivity. Compiled into iPhone and Watch targets.
/// Keep this file Foundation-only.

struct WatchState: Codable, Equatable {
    var openKey: String?
    var openFace: String?
    var openHex: String?
    var startMs: Double?
    var distracted: Bool
    var distractedMs: Double
    var groups: [WatchGroup]
}

struct WatchGroup: Codable, Equatable, Identifiable {
    var label: String
    var hex: String?
    var children: [WatchChild]
    var id: String { label }
}

struct WatchChild: Codable, Equatable, Identifiable {
    var label: String
    var hex: String?
    var id: String { label }
}

enum WatchCommand: Codable, Equatable {
    case propose(key: String)
    case toggleDistract
    case endDay
}

enum WatchWire {
    static let stateKey = "tt.watch.state"
    static let commandKey = "tt.watch.command"
}
