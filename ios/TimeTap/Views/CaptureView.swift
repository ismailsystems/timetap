import SwiftUI
import UIKit

struct CaptureView: View {
    @EnvironmentObject private var store: TapStore
    @State private var noteDraft = ""
    @State private var tick = Date()
    @State private var naming = false
    @State private var addDraft = ""
    @State private var catWidth: CGFloat = 96
    @State private var editingNote = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case note, add }

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
                nowPanel
                GeometryReader { geo in
                    let screen = geo.size.width > 1 ? geo.size.width : UIScreen.main.bounds.width
                    let catW = min(max(catWidth + 24, 128), screen * 0.67)
                    HStack(spacing: 0) {
                        DayRailView(
                            tick: tick,
                            onOpenTap: beginNoteEdit,
                            onOtherTap: finishNoteEdit
                        )
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .accessibilityElement(children: .contain)
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(Theme.rule2).frame(width: 2)
                            }
                        categoryList(height: geo.size.height)
                            .frame(width: catW)
                    }
                    .background(alignment: .topLeading) { categoryWidthProbe }
                    .onPreferenceChange(CatWidthKey.self) { catWidth = $0 }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.rule2).frame(height: 2)
                }
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

    private var nowPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(store.open.map { store.labelFor($0.key).uppercased() } ?? "NOTHING RUNNING")
                            .font(.system(size: 32, weight: .black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 8)
                        settingsButton
                    }
                    HStack(alignment: .center, spacing: 12) {
                        if store.open != nil {
                            Button {
                                finishNoteEdit()
                            } label: {
                                Text(elapsedLabel)
                                    .font(.system(size: 48, weight: .heavy))
                                    .foregroundStyle(isLong ? Theme.flag : Theme.accentOn)
                                    .monospacedDigit()
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("elapsed")
                            .accessibilityLabel(nowAccessibility)
                            .accessibilityHint("Dismisses the keyboard")
                            if showAddNote {
                                addNoteButton
                            }
                        } else {
                            Text("—")
                                .font(.system(size: 48, weight: .heavy))
                                .foregroundStyle(Theme.accentOn)
                                .accessibilityLabel(nowAccessibility)
                        }
                    }
                }
                if store.open != nil {
                    headerActions
                }
            }
            if showNoteField {
                noteField
            }
        }
        .padding(16)
        .padding(.horizontal, 2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rule2).frame(height: 2)
        }
    }

    private var settingsButton: some View {
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

    private var addNoteButton: some View {
        Button(action: beginNoteEdit) {
            Text("ADD NOTE")
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Theme.dim)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addNote")
        .accessibilityLabel("Add note")
        .accessibilityHint("Opens the note field")
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

    private var headerActions: some View {
        VStack(spacing: 8) {
            stopButton
            splitButton
        }
        .containerRelativeFrame(.horizontal, alignment: .trailing) { width, _ in width / 4 }
    }

    private var splitButton: some View {
        Button {
            finishNoteEdit()
            store.openSplit()
        } label: {
            outlineChip("SPLIT", fill: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("SPLIT")
        .accessibilityHint("Opens split sheet")
    }

    private var stopButton: some View {
        Button {
            finishNoteEdit()
            store.endDay()
        } label: {
            outlineChip("STOP", fill: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop the running block")
        .accessibilityHint("Does not stop sitting")
    }

    private var showNoteField: Bool {
        store.open != nil && (editingNote || focus == .note)
    }

    private var showAddNote: Bool {
        store.open != nil && !hasNote && !showNoteField
    }

    private var hasNote: Bool {
        let text = store.open?.text ?? noteDraft
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func categoryList(height: CGFloat) -> some View {
        let n = CGFloat(store.categories.count + 2)
        let rowH = max(44, height / max(n, 1))
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if store.canAddCategory {
                    addRow
                        .frame(maxWidth: .infinity, minHeight: rowH, maxHeight: rowH)
                        .overlay(alignment: .top) { Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1) }
                        .id("add")
                } else {
                    Text("That is \(store.config?.maxCategories ?? 10) categories already.")
                        .font(Theme.font(12, weight: .semibold))
                        .foregroundStyle(Theme.mute)
                        .padding(.leading, 12)
                        .padding(.trailing, 16)
                        .frame(maxWidth: .infinity, minHeight: rowH, maxHeight: rowH, alignment: .leading)
                        .overlay(alignment: .top) { Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1) }
                }

                ForEach(store.categories) { cat in
                    Button {
                        finishNoteEdit()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.tapCategory(cat.key)
                    } label: {
                        categoryRow(
                            face: cat.face,
                            hex: cat.hex,
                            dim: false,
                            running: store.open?.key == cat.key,
                            elapsed: elapsedLabel,
                            long: store.open?.key == cat.key && isLong
                        )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .background(store.open?.key == cat.key ? Theme.panel : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .frame(height: rowH)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1) }
                    .accessibilityLabel(cat.face)
                    .accessibilityAddTraits(store.open?.key == cat.key ? [.isSelected] : [])
                    .accessibilityValue(store.open?.key == cat.key ? elapsedLabel : "")
                    .id(cat.key)
                }

                sitChip
                    .frame(maxWidth: .infinity, minHeight: rowH, maxHeight: rowH)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1) }
                    .id("sit")
            }
        }
        .scrollDisabled(rowH > 44.5)
        .frame(maxHeight: .infinity)
        .onChange(of: store.scrollToKey) { _, _ in
            store.scrollToKey = nil
        }
        .onChange(of: naming) { _, on in
            if on { focus = .add }
        }
    }

    @ViewBuilder
    private var addRow: some View {
        if naming {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Theme.rule2)
                    .frame(width: 8, height: 18)
                TextField("name it", text: $addDraft)
                    .font(Theme.font(20, weight: .semibold))
                    .fontWidth(.standard)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .add)
                    .submitLabel(.done)
                    .onSubmit { commitAdd() }
                    .onAppear { focus = .add }
                    .disabled(store.addingCategory)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
        } else {
            Button {
                naming = true
            } label: {
                Text("+")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Theme.mute)
                    .offset(y: -1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Add a category")
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
                .padding(.bottom, 12)
                .accessibilityLabel("Undo: \(label)")
                .accessibilityHint("Available for \(store.undoSecondsLeft) seconds")
            }

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

    private var elapsedLabel: String {
        guard let open = store.open else { return "0m" }
        _ = tick
        return Format.shortElapsed(store.clock() - open.startMs)
    }

    private var isLong: Bool {
        guard let open = store.open else { return false }
        let ms = store.clock() - open.startMs
        return ms >= Double(store.config?.longBlockMinutes ?? 90) * 60_000
    }

    private var nowAccessibility: String {
        if let open = store.open {
            return "Now \(store.labelFor(open.key)), \(elapsedLabel), since \(Format.clock(open.startMs))"
        }
        return "Nothing running, time is unlogged"
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
                    .font(Theme.font(20, weight: .semibold))
                    .fontWidth(.standard)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Theme.fg)
                Spacer(minLength: 4)
                Text(postureElapsed)
                    .font(Theme.font(12, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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

    private func outlineChip(_ title: String, fill: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(Theme.accentOn)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: 44)
            .overlay(Rectangle().strokeBorder(Theme.rule2, lineWidth: 2))
    }

    private func markLabel(_ m: String) -> String {
        switch m {
        case "+": return "Mark good"
        case "=": return "Mark neutral"
        case "-": return "Mark poor"
        default: return "Mark \(m)"
        }
    }

    private func categoryRow(
        face: String, hex: String?, dim: Bool,
        running: Bool = false, elapsed: String = "", long: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(hex.map { Theme.hex($0) } ?? Theme.rule2)
                .frame(width: 8, height: 18)
                .accessibilityHidden(true)
            Text(face)
                .font(Theme.font(20, weight: .semibold))
                .fontWidth(.standard)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(long ? Theme.flag : (dim ? Theme.dim : Theme.fg))
            if running {
                Spacer(minLength: 4)
                Text(elapsed)
                    .font(Theme.font(12, weight: .bold).monospacedDigit())
                    .foregroundStyle(long ? Theme.flag : Theme.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(0)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
    }

    private var categoryWidthProbe: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.categories) { cat in
                categoryRow(face: cat.face, hex: cat.hex, dim: false)
                    .fixedSize()
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(key: CatWidthKey.self, value: g.size.width)
                        }
                    )
                categoryRow(
                    face: cat.face, hex: cat.hex, dim: false,
                    running: true, elapsed: "12h00", long: false
                )
                    .fixedSize()
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(key: CatWidthKey.self, value: g.size.width)
                        }
                    )
            }
        }
        .fixedSize()
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func commitFocus() {
        if focus == .add {
            commitAdd()
        } else {
            focus = nil
        }
    }

    private func commitAdd() {
        let name = addDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            naming = false
            addDraft = ""
            focus = nil
            return
        }
        store.addCategory(label: name) {
            naming = false
            addDraft = ""
            focus = nil
        }
    }
}

private struct CatWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
