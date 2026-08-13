import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TapStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            CaptureView()
        }
        .sheet(isPresented: $store.showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $store.showSignIn) {
            SignInView()
                .environmentObject(store)
        }
        .onAppear { store.boot() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshOnReturn() }
        }
        .onOpenURL { url in
            _ = GoogleAuth.handleURL(url)
        }
    }
}
