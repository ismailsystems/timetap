import SwiftUI

struct CalendarPickerView: View {
    @EnvironmentObject private var store: TapStore
    @Environment(\.dismiss) private var dismiss
    var embedded = false
    @State private var pick = CalendarAPI.Pick.loaded([])
    @State private var errorText: String?
    @State private var loading = true

    var body: some View {
        Group {
            if embedded {
                form
            } else {
                NavigationStack { form }
                    .interactiveDismissDisabled()
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    private var form: some View {
        Form {
            if loading {
                ProgressView()
            } else if pick.list.isEmpty {
                Text(errorText == nil
                     ? "Create calendars named PLAN, ACTUAL and SITTING in Google Calendar, then tap Retry."
                     : "Could not load calendars.")
                    .foregroundStyle(Theme.mute)
            } else {
                slot("PLAN", selection: $pick.planId)
                slot("ACTUAL", selection: $pick.actualId)
                slot("SITTING", selection: $pick.sittingId)
            }
            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(Theme.accentOn)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle("Calendars")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !embedded {
                ToolbarItem(placement: .cancellationAction) {
                    if Credentials.hasCalendarIds {
                        Button("Close") { store.showPicker = false }
                    } else {
                        Button("Sign out") {
                            store.signOut()
                            store.showPicker = false
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Text(pick.firstMatchRule)
                    .font(.footnote)
                    .foregroundStyle(Theme.mute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Retry") { Task { await load() } }
                    .frame(maxWidth: .infinity)
                Button("Confirm") { confirm() }
                    .disabled(!pick.canConfirm)
                    .frame(maxWidth: .infinity)
                if !pick.canConfirm, !loading, pick.emptyLabel == nil {
                    Text("Choose all three calendars.")
                        .font(.footnote)
                        .foregroundStyle(Theme.mute)
                }
            }
            .padding()
            .background(Theme.ground)
        }
    }

    private func slot(_ title: String, selection: Binding<String?>) -> some View {
        Picker(title, selection: selection) {
            Text("—").tag(String?.none)
            ForEach(pick.list) { cal in
                Text(cal.summary).tag(Optional(cal.id))
            }
        }
    }

    private func load() async {
        loading = true
        errorText = nil
        defer { loading = false }
        switch await store.loadCalendars() {
        case .success(let list):
            pick = .fromSaved(list)
        case .failure(let error):
            errorText = error.localizedDescription
        }
    }

    private func confirm() {
        Task {
            await store.confirmCalendars(
                plan: pick.planId, actual: pick.actualId, sitting: pick.sittingId
            )
            if embedded { dismiss() }
        }
    }
}
