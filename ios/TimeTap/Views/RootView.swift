import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TapStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            if store.sessionReady {
                CaptureView()
            } else {
                ProgressView()
                    .tint(Theme.accentOn)
            }
        }
        .sheet(isPresented: $store.showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $store.showSignIn) {
            SignInView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $store.showPicker) {
            CalendarPickerView()
                .environmentObject(store)
        }
        .onAppear {
            if TimeTapApp.isUISmoke { return }
            GoogleAuth.restore { store.boot() }
        }
        .onChange(of: scenePhase) { _, phase in
            if TimeTapApp.isUISmoke { return }
            if phase == .active { store.refreshOnReturn() }
        }
        .onOpenURL { url in
            _ = GoogleAuth.handleURL(url)
        }
    }
}
