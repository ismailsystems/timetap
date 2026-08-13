import SwiftUI

@main
struct TimeTapApp: App {
    @StateObject private var store: TapStore

    init() {
        GoogleAuth.configure()
        let store = TapStore()
        _store = StateObject(wrappedValue: store)
        LiveActivityActions.toggleSit = { await store.handleSitIntent() }
        LiveActivityActions.stopSit = { await store.handleStopSitIntent() }
        LiveActivityActions.endDay = { await store.handleStopIntent() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
