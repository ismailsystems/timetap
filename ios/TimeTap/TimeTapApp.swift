import SwiftUI

@main
struct TimeTapApp: App {
    @StateObject private var store = TapStore()

    init() {
        GoogleAuth.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
