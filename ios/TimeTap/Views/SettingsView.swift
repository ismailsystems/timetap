import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TapStore
    @Environment(\.dismiss) private var dismiss

    @State private var url: String = Credentials.apiURL
    @State private var token: String = Credentials.apiToken
    @State private var probe: String?
    @State private var probing = false

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

                if let tz = store.config?.tz {
                    Section("Server") {
                        LabeledContent("Timezone", value: tz)
                        LabeledContent("Categories", value: "\(store.categories.count)")
                    }
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

                    Button {
                        Task { await probeConnection() }
                    } label: {
                        if probing {
                            ProgressView()
                        } else {
                            Text("Test connection")
                        }
                    }
                    .disabled(
                        probing
                            || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    if let probe {
                        Text(probe)
                            .font(.footnote)
                            .foregroundStyle(probe.hasPrefix("OK") ? Color.green : Theme.accentOn)
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

    private func probeConnection() async {
        probing = true
        defer { probing = false }
        Credentials.apiURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        Credentials.apiToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let cfg = try await TimetapAPI.shared.config()
            probe = "OK — \(cfg.categories.count) categories, tz \(cfg.tz)"
        } catch {
            probe = error.localizedDescription
        }
    }
}
