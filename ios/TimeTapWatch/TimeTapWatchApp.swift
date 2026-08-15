import SwiftUI

@main
struct TimeTapWatchApp: App {
    @StateObject private var session = WatchSession()

    var body: some Scene {
        WindowGroup {
            WatchCaptureView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
        }
    }
}
