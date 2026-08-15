import Foundation

#if os(macOS)
/// Mac compile stub. Live Activities stay on the iPhone.
enum RunningBlockAttributes {
    struct ContentState {
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
    }
}

enum RunningBlockSync {
    static func apply(_ state: RunningBlockAttributes.ContentState?) async {}
}
#endif
