import AppIntents
import Foundation
import notify

/// Widget and app both post Darwin. The app observes in `TimeTapApp.init`.
enum LiveActivityDarwin {
    static let toggleSit = "app.timetap.ios.toggleSit"
    static let stopSit = "app.timetap.ios.stopSit"
    static let endDay = "app.timetap.ios.endDay"

    static var onToggleSit: (() -> Void)?
    static var onStopSit: (() -> Void)?
    static var onEndDay: (() -> Void)?

    private static var observing = false
    private static var tokens: [Int32] = []

    static func post(_ name: String) {
        notify_post(name)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    static func observe(
        toggleSit: @escaping () -> Void,
        stopSit: @escaping () -> Void,
        endDay: @escaping () -> Void
    ) {
        onToggleSit = toggleSit
        onStopSit = stopSit
        onEndDay = endDay
        guard !observing else { return }
        observing = true
        for name in [Self.toggleSit, Self.stopSit, Self.endDay] {
            var token: Int32 = 0
            notify_register_dispatch(name, &token, .main) { _ in
                switch name {
                case LiveActivityDarwin.toggleSit: LiveActivityDarwin.onToggleSit?()
                case LiveActivityDarwin.stopSit: LiveActivityDarwin.onStopSit?()
                case LiveActivityDarwin.endDay: LiveActivityDarwin.onEndDay?()
                default: break
                }
            }
            tokens.append(token)
        }
    }
}

struct ToggleSitIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Sit"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        LiveActivityDarwin.post(LiveActivityDarwin.toggleSit)
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
        LiveActivityDarwin.post(LiveActivityDarwin.stopSit)
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
        LiveActivityDarwin.post(LiveActivityDarwin.endDay)
        return .result()
    }
}
