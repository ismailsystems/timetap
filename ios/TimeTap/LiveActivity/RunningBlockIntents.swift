import AppIntents
import Foundation

enum LiveActivityActions {
    /// App process fills these in `TimeTapApp.init`. Widget keeps the empty defaults.
    static var toggleSit: () async -> Void = {}
    static var stopSit: () async -> Void = {}
    static var endDay: () async -> Void = {}
}

struct ToggleSitIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Sit"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await LiveActivityActions.toggleSit()
        return .result()
    }
}

struct StopSitIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop sitting"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await LiveActivityActions.stopSit()
        return .result()
    }
}

struct StopBlockIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        await LiveActivityActions.endDay()
        return .result()
    }
}
