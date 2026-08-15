import SwiftUI

@main
struct TimeTapMacApp: App {
    @StateObject private var store: TapStore

    init() {
        GoogleAuth.configure()
        let store = TapStore()
        if TimeTapRuntime.isUnderTest {
            store.sessionReady = true
            store.showSignIn = false
            store.showPicker = false
        } else {
            MacCommandHub.store = store
            StatusItemController.start(store: store)
        }
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1100, height: 720)
        .commands { MacCommands() }
        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
