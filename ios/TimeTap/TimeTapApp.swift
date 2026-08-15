import SwiftUI

@main
struct TimeTapApp: App {
    @StateObject private var store: TapStore

    static var isUISmoke: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-tt-ui-smoke")
        #else
        false
        #endif
    }

    init() {
        GoogleAuth.configure()
        if Self.isUISmoke {
            GoogleAuth.testHasSession = true
            GoogleAuth.testAccessToken = "smoke"
            Credentials.planId = "p1"
            Credentials.actualId = "a1"
            Credentials.sittingId = "s1"
        }
        let store = TapStore()
        if Self.isUISmoke {
            store.open = OpenBlock(ref: "ui-smoke", key: "Deep work", text: "", startMs: store.clock())
            store.sit = nil
            store.showSignIn = false
            store.showPicker = false
            store.sessionReady = true
            store.banner = nil
        }
        _store = StateObject(wrappedValue: store)
        LiveActivityDarwin.observe(
            toggleSit: { Task { await store.handleSitIntent() } },
            stopSit: { Task { await store.handleStopSitIntent() } },
            endDay: { Task { await store.handleStopIntent() } }
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
