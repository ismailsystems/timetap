import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TapStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("Edit categories") {
                        CategoryEditor()
                    }
                    .accessibilityHint("Opens the category list")
                } footer: {
                    Text("A category you add in Settings stays on this phone. The web app does not show it.")
                }

                Section {
                    NavigationLink {
                        CalendarPickerView(embedded: true)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calendars")
                            calendarRow("PLAN", id: Credentials.planId)
                            calendarRow("ACTUAL", id: Credentials.actualId)
                            calendarRow("SITTING", id: Credentials.sittingId)
                        }
                    }
                    .accessibilityHint("Opens the calendar picker. Settings stays.")
                } footer: {
                    Text("The later write replaces the earlier write on that event.")
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        store.signOut()
                    }
                    .accessibilityHint("Signs out and returns to capture")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .foregroundStyle(Theme.fg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityHint("Returns to capture")
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func calendarRow(_ title: String, id: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.dim)
            Spacer()
            Text(id.isEmpty ? "—" : "Set")
                .foregroundStyle(Theme.dim)
        }
        .font(.footnote)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(id.isEmpty ? "not set" : "set")")
    }
}
