import SwiftUI

struct DeadLetterSheet: View {
    @EnvironmentObject private var store: TapStore
    @State private var armedToken: String?
    @State private var armTask: Task<Void, Never>?
    @State private var armedAt: TimeInterval = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SET ASIDE · \(store.deadCount)")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.0)
                Spacer()
                Button("CLOSE") {
                    disarm()
                    store.showDead = false
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.dim)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule2).frame(height: 2) }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(store.dead.reversed()) { entry in
                        deadRow(entry)
                        Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1)
                    }
                }
            }

            Text("A SET-ASIDE WRITE IS THE ONLY RECORD IT EVER HAPPENED — DISCARD ONLY AFTER FIXING THE CALENDAR BY HAND")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Theme.mute)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(Theme.rule2).frame(height: 2) }
        }
        .foregroundStyle(Theme.fg)
        .background(Theme.ground.ignoresSafeArea())
    }

    private func deadRow(_ e: DeadEntry) -> some View {
        let key = store.labelFor(e.key ?? e.op.key ?? "").uppercased()
        let when = Format.clock(e.at)
        let started = e.startMs.map(Format.clock) ?? "unknown start"
        let what = Format.opWords[e.op.type] ?? e.op.type

        return VStack(alignment: .leading, spacing: 8) {
            Text("\(when) · \(key.isEmpty ? "unknown category" : key)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.dim)
            Text("tried to \(what), block started \(started)")
                .font(.system(size: 14, weight: .semibold))
            Text(e.why)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accentOn)
            Button {
                armOrDiscard(e.token)
            } label: {
                Text(armedToken == e.token ? "TAP AGAIN TO DISCARD" : "DISCARD")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.0)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.vertical, 12)
                    .background(armedToken == e.token ? Theme.accent : Theme.panel2)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
    }

    private func armOrDiscard(_ token: String) {
        if armedToken == token {
            if Date().timeIntervalSince1970 - armedAt < 0.3 { return }
            disarm()
            store.discardDead(token: token)
            return
        }
        disarm()
        armedToken = token
        armedAt = Date().timeIntervalSince1970
        let ms = store.config?.confirmTimeoutMs ?? 4000
        armTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { armedToken = nil }
        }
    }

    private func disarm() {
        armTask?.cancel()
        armTask = nil
        armedToken = nil
    }
}
