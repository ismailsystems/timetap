import AppKit
import SwiftUI

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { MacCommandHub.openMain?() }
        return true
    }
}

private struct MacWindowOpener: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                MacCommandHub.openMain = { openWindow(id: "main") }
            }
    }
}

@main
struct TimeTapMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
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
        WindowGroup(id: "main") {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 560)
                .background(MacWindowOpener())
        }
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified)
        .commands { MacCommands() }
        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
