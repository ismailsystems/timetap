import SwiftUI

@main
struct TimeTapApp: App {
    @StateObject private var store = TapStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
