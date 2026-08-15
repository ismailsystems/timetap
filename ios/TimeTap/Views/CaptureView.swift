import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var store: TapStore
    @State private var noteDraft = ""
    @State private var tick = Date()
    @State private var editingNote = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case note }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let banner = store.banner {
                    Button {
                        store.openDeadDrawer()
                    } label: {
                        Text(banner)
                            .font(Theme.font(11, weight: .bold))
                            .foregroundStyle(Theme.accentOn)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Theme.fail)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.deadCount == 0)
                    .accessibilityLabel(banner)
                }
                titleBar
                GeometryReader { _ in
                    HStack(alignment: .top, spacing: 0) {
                        DayRailView(source: .plan, tick: tick)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        DayRailView(
                            source: .actual,
                            tick: tick,
                            onOpenTap: beginNoteEdit,
                            onOtherTap: finishNoteEdit
                        )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.bottom, 5)
                footer
            }
            .foregroundStyle(Theme.fg)
            .ignoresSafeArea(.keyboard, edges: focus == nil ? .bottom : [])
            .toolbar(.hidden, for: .navigationBar)
        }
        .onReceive(timer) { tick = $0 }
        .onChange(of: store.open?.ref) { _, _ in
            editingNote = false
            if focus != .note {
                noteDraft = store.open?.text ?? ""
            }
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

    private var titleBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text("TimeTap")
                    .font(Theme.rowFont(22, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    finishNoteEdit()
                    store.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .accessibilityHint("Opens settings")
            }
            if showNoteField {
                noteField
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var noteField: some View {
        TextField("note", text: $noteDraft)
            .focused($focus, equals: .note)
            .submitLabel(.done)
            .onSubmit { finishNoteEdit() }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Theme.panel2)
            .onChange(of: noteDraft) { _, val in
                store.noteChanged(val)
            }
            .onChange(of: store.open?.text) { _, text in
                if focus != .note { noteDraft = text ?? "" }
            }
            .accessibilityIdentifier("noteField")
            .accessibilityLabel("Note for the running block")
    }

    private var showNoteField: Bool {
        store.open != nil && (editingNote || focus == .note)
    }

    private func beginNoteEdit() {
        guard store.open != nil else { return }
        editingNote = true
        focus = .note
    }

    private func finishNoteEdit() {
        focus = nil
        editingNote = false
    }

    private var footer: some View {
        VStack(spacing: 0) {
            sitChip
                .overlay(alignment: .top) { Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1) }
            if let strip = store.markStrip {
                VStack(spacing: 0) {
                    Text("\(store.labelFor(strip.key).uppercased()) · \(Format.elapsed(strip.durMs)) — MARK IT")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                        .accessibilityIdentifier("stripHead")
                    HStack(spacing: 0) {
                        ForEach(["+", "=", "-"], id: \.self) { m in
                            Button { store.applyMark(m) } label: {
                                Text(m)
                                    .font(.system(size: 28, weight: .black))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(markLabel(m)) \(store.labelFor(strip.key))")
                        }
                    }
                }
                .background(Theme.panel)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.rule2).frame(height: 2)
                }
            }
        }
    }

    private var postureElapsed: String {
        _ = tick
        let start = store.sit?.startMs ?? store.standStartMs
        guard let start else { return "0m" }
        return Format.shortElapsed(store.clock() - start)
    }

    @ViewBuilder
    private var sitChip: some View {
        let sitting = store.sit != nil
        Button {
            finishNoteEdit()
            store.toggleSit()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: Theme.postureSymbol(sitting: sitting))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Text(sitting ? "SITTING" : "NOT SITTING")
                    .font(Theme.rowFont(20, weight: .semibold))
                    .fontWidth(.standard)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Theme.fg)
                Spacer(minLength: 4)
                Text(postureElapsed)
                    .font(Theme.rowFont(12, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(Theme.panel)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sitChip")
        .accessibilityAddTraits(.isSelected)
        .accessibilityValue(sitting ? "SITTING" : "NOT SITTING")
        .accessibilityLabel(sitting ? "Sitting for \(postureElapsed)" : "Not sitting for \(postureElapsed)")
        .accessibilityHint(
            sitting
                ? "Stops sitting. Long press to adjust when sitting started."
                : "Starts sitting"
        )
        .contextMenu {
            if sitting {
                Button("Adjust sitting start") { store.openSitEdit() }
            }
        }
    }

    private func markLabel(_ m: String) -> String {
        switch m {
        case "+": return "Mark good"
        case "=": return "Mark neutral"
        case "-": return "Mark poor"
        default: return "Mark \(m)"
        }
    }
}
