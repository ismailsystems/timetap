import SwiftUI

struct CalendarPickerView: View {
    @EnvironmentObject private var store: TapStore
    @State private var pick = CalendarAPI.Pick.loaded([])
    @State private var errorText: String?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Form {
                if loading {
                    ProgressView()
                } else if let empty = pick.emptyLabel {
                    Text(empty)
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
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if Credentials.hasCalendarIds {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { store.showPicker = false }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Text(pick.firstMatchRule)
                        .font(.footnote)
                        .foregroundStyle(Theme.mute)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if errorText != nil {
                        Button("Retry") { Task { await load() } }
                            .frame(maxWidth: .infinity)
                    }
                    Button("Confirm") { confirm() }
                        .disabled(!pick.canConfirm)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Theme.ground)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .task { await load() }
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
        do {
            pick = .fromSaved(try await CalendarAPI.listCalendars())
        } catch {
            errorText = error.localizedDescription
            pick = .loaded([])
        }
    }

    private func confirm() {
        guard CalendarAPI.confirm(plan: pick.planId, actual: pick.actualId, sitting: pick.sittingId) else { return }
        Task { await store.didConfirmCalendars() }
    }
}
