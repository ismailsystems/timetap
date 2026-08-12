import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var store: TapStore
    @State private var noteDraft = ""
    @State private var tick = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            nowPanel
            categoryList
            footer
        }
        .foregroundStyle(Theme.fg)
        .onReceive(timer) { tick = $0 }
        .onChange(of: store.open?.ref) { _, _ in
            noteDraft = store.open?.text ?? ""
        }
        .onAppear { noteDraft = store.open?.text ?? "" }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("TIMETAP")
                .font(.system(size: 15, weight: .heavy))
                .tracking(1.2)
            Spacer()
            Button {
                store.showSettings = true
            } label: {
                Text(store.syncLabel)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(store.syncFailed ? Theme.accentOn : Theme.dim)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rule2).frame(height: 2)
        }
    }

    private var nowPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(store.open == nil ? "NOTHING RUNNING" : "NOW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.dim)
                Spacer()
            }
            Text(store.open.map { store.labelFor($0.key).uppercased() } ?? "—")
                .font(.system(size: 32, weight: .black))
                .padding(.top, 8)
            Text(elapsedLabel)
                .font(.system(size: 48, weight: .heavy))
                .foregroundStyle(isLong ? Theme.flag : Theme.accentOn)
                .monospacedDigit()
                .padding(.top, 8)

            TextField("note", text: $noteDraft, axis: .vertical)
                .lineLimit(1...3)
                .padding(11)
                .frame(minHeight: 44)
                .background(Theme.panel2)
                .disabled(store.open == nil)
                .opacity(store.open == nil ? 0.4 : 1)
                .padding(.top, 12)
                .onChange(of: noteDraft) { _, val in
                    store.noteChanged(val)
                }
        }
        .padding(16)
        .padding(.horizontal, 2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rule2).frame(height: 2)
        }
    }

    private var categoryList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.config?.categories ?? []) { cat in
                    Button {
                        store.tapCategory(cat.key)
                    } label: {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Theme.hex(cat.hex))
                                .frame(width: 12, height: 28)
                            Text(cat.face.uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .tracking(0.6)
                            Spacer()
                            if store.open?.key == cat.key {
                                Text("RUNNING")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.2)
                                    .foregroundStyle(Theme.accentOn)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let label = store.undoLabel {
                Button(action: store.takeUndo) {
                    HStack {
                        Text(label)
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(1.0)
                        Spacer()
                        Text("UNDO · \(store.undoSecondsLeft)")
                            .font(.system(size: 12, weight: .heavy))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            if store.markStrip != nil {
                HStack(spacing: 0) {
                    ForEach(["+", "=", "-"], id: \.self) { m in
                        Button {
                            store.applyMark(m)
                        } label: {
                            Text(m)
                                .font(.system(size: 28, weight: .black))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Theme.panel)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.rule2).frame(height: 2)
                }
            }

            if let banner = store.banner {
                Text(banner)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accentOn)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
            }

            HStack(spacing: 0) {
                Button(action: store.toggleSit) {
                    Text(store.sit == nil ? "NOT SITTING" : "SITTING")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(store.sit == nil ? Theme.mute : Theme.accentOn)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)

                Rectangle().fill(Theme.rule2).frame(width: 2)

                Button(action: store.endDay) {
                    Text("STOP")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(store.open == nil && store.sit == nil ? Theme.mute : Theme.fg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .disabled(store.open == nil && store.sit == nil)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.rule2).frame(height: 2)
            }
        }
    }

    private var elapsedLabel: String {
        guard let open = store.open else { return "0m" }
        _ = tick
        let ms = max(0, Date().timeIntervalSince1970 * 1000 - open.startMs)
        let m = Int(ms / 60_000)
        let h = m / 60
        if h > 0 {
            return "\(h)h" + String(format: "%02d", m % 60)
        }
        return "\(m)m"
    }

    private var isLong: Bool {
        guard let open = store.open else { return false }
        let ms = Date().timeIntervalSince1970 * 1000 - open.startMs
        return ms >= Double(store.config?.longBlockMinutes ?? 90) * 60_000
    }
}
