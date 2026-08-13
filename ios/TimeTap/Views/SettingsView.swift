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
