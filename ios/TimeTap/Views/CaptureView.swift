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
            HStack(spacing: 0) {
                DayRailView(tick: tick)
                    .frame(width: 140)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(Theme.rule2).frame(width: 2)
                    }
                categoryList
            }
            .frame(maxHeight: .infinity)
            footer
        }
        .foregroundStyle(Theme.fg)
        .onReceive(timer) { tick = $0 }
        .onChange(of: store.open?.ref) { _, _ in
            noteDraft = store.open?.text ?? ""
        }
        .onAppear { noteDraft = store.open?.text ?? "" }
        .fullScreenCover(isPresented: Binding(
            get: { store.split != nil },
            set: { if !$0 { store.split = nil } }
        )) {
            SplitSheet().environmentObject(store)
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.sitEdit != nil },
            set: { if !$0 { store.sitEdit = nil } }
        )) {
            SitEditSheet().environmentObject(store)
        }
        .fullScreenCover(isPresented: $store.showDead) {
            DeadLetterSheet().environmentObject(store)
        }
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
            Button {
                if store.open != nil { store.openSplit() }
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(store.open == nil ? "NOTHING RUNNING" : "NOW")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(Theme.dim)
                        Spacer()
                        if store.open != nil {
                            Text("TAP TO SPLIT")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.0)
                                .foregroundStyle(Theme.mute)
                        }
                    }
                    Text(store.open.map { store.labelFor($0.key).uppercased() } ?? "—")
                        .font(.system(size: 32, weight: .black))
                        .padding(.top, 8)
                    Text(elapsedLabel)
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundStyle(isLong ? Theme.flag : Theme.accentOn)
                        .monospacedDigit()
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
                ForEach(store.categories) { cat in
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
                                Text(elapsedLabel)
                                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                                    .foregroundStyle(isLong ? Theme.flag : Theme.accentOn)
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
                        Button { store.applyMark(m) } label: {
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
                Button {
                    store.openDeadDrawer()
                } label: {
                    Text(banner)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accentOn)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .disabled(store.deadCount == 0)
            }

            HStack(spacing: 0) {
                Button(action: store.toggleSit) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(store.sit == nil ? Theme.rule2 : Theme.accent)
                            .frame(width: 10, height: 10)
                        Text(store.sit == nil ? "NOT SITTING" : "SITTING")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(store.sit == nil ? Theme.mute : Theme.accentOn)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)

                if let sit = store.sit {
                    Button(action: store.openSitEdit) {
                        Text(Format.elapsed(Date().timeIntervalSince1970 * 1000 - sit.startMs))
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .overlay(Rectangle().strokeBorder(Theme.rule2, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }

                if store.open != nil || store.sit != nil {
                    Button(action: store.endDay) {
                        Text("STOP")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(Theme.accentOn)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .overlay(Rectangle().strokeBorder(Theme.rule2, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.rule2).frame(height: 2)
            }
        }
    }

    private var elapsedLabel: String {
        guard let open = store.open else { return "0m" }
        _ = tick
        return Format.elapsed(Date().timeIntervalSince1970 * 1000 - open.startMs)
    }

    private var isLong: Bool {
        guard let open = store.open else { return false }
        let ms = Date().timeIntervalSince1970 * 1000 - open.startMs
        return ms >= Double(store.config?.longBlockMinutes ?? 90) * 60_000
    }
}
