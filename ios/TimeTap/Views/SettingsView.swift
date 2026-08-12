import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TapStore
    @Environment(\.dismiss) private var dismiss

    @State private var url: String = Credentials.apiURL
    @State private var token: String = Credentials.apiToken

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Web app /exec URL", text: $url, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...4)
                    SecureField("API_TOKEN", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Native API")
                } footer: {
                    Text(
                        "Use the Anyone (anonymous) deployment URL from Apps Script. " +
                        "Set script property API_TOKEN to the same secret. " +
                        "See ios/README.md."
                    )
                }

                Section {
                    Button("Save and connect") {
                        store.saveSettingsAndReconnect(url: url, token: token)
                        dismiss()
                    }
                    .disabled(
                        url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
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
