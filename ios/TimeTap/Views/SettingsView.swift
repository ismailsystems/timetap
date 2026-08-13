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
                    Text("If the web app and this phone both write, last write wins. Categories you add here do not appear on the web app.")
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
