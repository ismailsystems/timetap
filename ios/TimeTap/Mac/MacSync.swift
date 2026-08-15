import Foundation

/// Locked Mac defaults. Calendar is the sync bus for iPhone, Mac, and Watch.
/// Watch still radios through the iPhone. The Mac never activates WCSession.
enum MacSync {
    /// Poll while the Mac window is frontmost.
    static let activePollNs: UInt64 = 15_000_000_000
    /// Poll while the Mac app is in the background.
    static let idlePollNs: UInt64 = 60_000_000_000

    static func pollNs(active: Bool) -> UInt64 {
        active ? activePollNs : idlePollNs
    }
}

enum TimeTapRuntime {
    static var isUISmoke: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-tt-ui-smoke")
        #else
        false
        #endif
    }

    static var isUnderTest: Bool {
        NSClassFromString("XCTestCase") != nil
    }
}
