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
        #if os(macOS)
        .sheet(isPresented: $store.showSignIn) {
            SignInView()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showPicker) {
            CalendarPickerView()
                .environmentObject(store)
        }
        #else
        .fullScreenCover(isPresented: $store.showSignIn) {
            SignInView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $store.showPicker) {
            CalendarPickerView()
                .environmentObject(store)
        }
        #endif
        .onAppear {
            if TimeTapRuntime.isUISmoke { return }
            GoogleAuth.restore { store.boot() }
            store.startCalendarPoll()
        }
        .onDisappear {
            if TimeTapRuntime.isUISmoke { return }
            store.stopCalendarPoll()
        }
        .onChange(of: scenePhase) { _, phase in
            if TimeTapRuntime.isUISmoke { return }
            if phase == .active {
                store.pollActive = true
                store.refreshOnReturn()
            } else {
                store.pollActive = false
            }
        }
        .onOpenURL { url in
            _ = GoogleAuth.handleURL(url)
        }
    }
}
