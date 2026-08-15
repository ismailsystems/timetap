import SwiftUI

struct SitEditSheet: View {
    @EnvironmentObject private var store: TapStore
    @State private var armed = false
    @State private var armTask: Task<Void, Never>?
    @State private var armedAt: TimeInterval = 0
    @State private var confirmDelete = false

    var body: some View {
        if let s = store.sitEdit {
            let span = max(1, Int(((s.hi - s.lo) / 60_000).rounded()))
            let mins = max(0, Int(((s.atMs - s.lo) / 60_000).rounded()))

            VStack(spacing: 0) {
                HStack {
                    Text("SITTING STARTED")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.0)
                    Spacer()
                    Button("CLOSE") { store.sitEdit = nil }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.dim)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule2).frame(height: 2) }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(Format.clock(s.lo)).foregroundStyle(Theme.dim)
                        Spacer()
                        Text(Format.clock(s.atMs))
                            .foregroundStyle(Theme.accentOn)
                            .fontWeight(.bold)
                        Spacer()
                        Text(Format.clock(s.hi)).foregroundStyle(Theme.dim)
                    }
                    .font(.system(size: 12, weight: .bold).monospacedDigit())

                    Slider(
                        value: Binding(
                            get: { Double(mins) },
                            set: { store.setSitEditMinutes(Int($0.rounded())) }
                        ),
                        in: 0...Double(span),
                        step: 1
                    )
                    .tint(Theme.accent)

                    Text("sitting for \(Format.duration(store.clock() - s.atMs)) if applied")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                }
                .padding(18)

                Spacer()

                Button(action: store.applySitEdit) {
                    Text("APPLY")
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(1.4)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)

                Button(role: .destructive, action: requestDelete) {
                    Text(armed ? "TAP AGAIN TO DELETE" : "DELETE SITTING")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(armed ? Theme.accent : Color.clear)
                        .foregroundStyle(armed ? Color.white : Theme.accentOn)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Theme.fg)
            .background(Theme.ground.ignoresSafeArea())
            .onDisappear { disarm() }
            #if os(macOS)
            .confirmationDialog(
                "Delete this sitting block?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete sitting", role: .destructive) { store.deleteSit() }
                Button("Cancel", role: .cancel) { confirmDelete = false }
            }
            #endif
        }
    }

    private func requestDelete() {
        #if os(macOS)
        confirmDelete = true
        #else
        armOrDelete()
        #endif
    }

    private func armOrDelete() {
        if armed {
            if Date().timeIntervalSince1970 - armedAt < 0.3 { return }
            disarm()
            store.deleteSit()
            return
        }
        disarm()
        armed = true
        armedAt = Date().timeIntervalSince1970
        let ms = store.config?.confirmTimeoutMs ?? 4000
        armTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { armed = false }
        }
    }

    private func disarm() {
        armTask?.cancel()
        armTask = nil
        armed = false
    }
}
