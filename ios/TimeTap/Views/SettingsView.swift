import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TapStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let tz = store.config?.tz {
                    Section("Device") {
                        LabeledContent("Timezone", value: tz)
                        LabeledContent("Categories", value: "\(store.categories.count)")
                    }
                }
                Section("Calendars") {
                    Button("Change PLAN, ACTUAL, SITTING") {
                        store.showSettings = false
                        store.showPicker = true
                    }
                }
                Section("This phone and the web app") {
                    Text("This phone and the web app both write Google Calendar. The later write replaces the earlier write on that event.")
                    Text("A category you add on the capture grid stays on this phone. The web app does not show it.")
                }
                Section {
                    Button("Sign out", role: .destructive) {
                        store.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
