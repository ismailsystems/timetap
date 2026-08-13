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
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.accentOn)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
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
                            .accessibilityLabel("Day rail")
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(Theme.rule2).frame(width: 2)
                            }
                        categoryList
                            .frame(width: catW)
                    }
                    .background(alignment: .topLeading) { categoryWidthProbe }
                    .onPreferenceChange(CatWidthKey.self) { catWidth = $0 }
                }
                .frame(maxHeight: .infinity)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.nowKick)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(Theme.dim)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Button {
                    finishNoteEdit()
                    store.showSettings = true
                } label: {
                    Text(store.syncLabel)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(store.syncFailed ? Theme.accentOn : Theme.dim)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.syncLabel)
                .accessibilityHint("Opens settings")
            }
            HStack(alignment: .firstTextBaseline) {
                Text(store.open.map { store.labelFor($0.key).uppercased() } ?? "NOTHING RUNNING")
                    .font(.system(size: 32, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                if store.open != nil {
                    Button {
                        finishNoteEdit()
                        store.openSplit()
                    } label: {
                        Text("TAP TO SPLIT")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.0)
                            .foregroundStyle(Theme.mute)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("TAP TO SPLIT")
                    .accessibilityHint("Opens split sheet")
                }
            }
            .padding(.top, 8)
            Button {
                finishNoteEdit()
            } label: {
                Text(store.open == nil ? "—" : elapsedLabel)
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(isLong ? Theme.flag : Theme.accentOn)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .accessibilityLabel(nowAccessibility)
            .accessibilityHint("Dismisses the keyboard")

            if showNoteField {
                TextField("note", text: $noteDraft)
                    .focused($focus, equals: .note)
                    .submitLabel(.done)
                    .onSubmit { finishNoteEdit() }
                    .padding(11)
                    .frame(minHeight: 44)
                    .background(Theme.panel2)
                    .padding(.top, 12)
                    .onChange(of: noteDraft) { _, val in
                        store.noteChanged(val)
                    }
                    .onChange(of: store.open?.text) { _, text in
                        if focus != .note { noteDraft = text ?? "" }
                    }
                    .accessibilityLabel("Note for the running block")
            }
        }
        .padding(16)
        .padding(.horizontal, 2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rule2).frame(height: 2)
        }
    }

    private var showNoteField: Bool {
        guard store.open != nil else { return false }
        if editingNote || focus == .note { return true }
        return noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.canAddCategory {
                addRow
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .id("add")
            } else {
                Text("That is \(store.config?.maxCategories ?? 10) categories already.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.mute)
                    .padding(.leading, 12)
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            ForEach(store.categories) { cat in
                Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1)
                Button {
                    finishNoteEdit()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.tapCategory(cat.key)
                } label: {
                    categoryRow(face: cat.face, hex: cat.hex, dim: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(store.open?.key == cat.key ? Theme.panel : Color.clear)
                }
                .buttonStyle(.plain)
                .frame(maxHeight: .infinity)
                .accessibilityLabel(cat.face)
                .accessibilityAddTraits(store.open?.key == cat.key ? [.isSelected] : [])
                .accessibilityValue(store.open?.key == cat.key ? elapsedLabel : "")
                .id(cat.key)
            }
        }
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
                    .font(.system(size: 20, weight: .semibold))
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
                categoryRow(face: "New", hex: nil, dim: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                .accessibilityLabel("Undo: \(label)")
                .accessibilityHint("Available for \(store.undoSecondsLeft) seconds")
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
                        .accessibilityLabel(markLabel(m))
                    }
                }
                .background(Theme.panel)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.rule2).frame(height: 2)
                }
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.sit == nil ? "Not sitting" : "Sitting")
                .accessibilityHint("Toggles sitting posture")
                .accessibilityAddTraits(.isButton)

                if let sit = store.sit {
                    Button(action: store.openSitEdit) {
                        Text(Format.elapsed(Date().timeIntervalSince1970 * 1000 - sit.startMs))
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .overlay(Rectangle().strokeBorder(Theme.rule2, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "Adjust when sitting started, sitting for \(Format.elapsed(Date().timeIntervalSince1970 * 1000 - sit.startMs))"
                    )
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
                    .accessibilityLabel("End the day")
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

    private var nowAccessibility: String {
        if let open = store.open {
            return "Now \(store.labelFor(open.key)), \(elapsedLabel), since \(Format.clock(open.startMs))"
        }
        return "Nothing running, time is unlogged"
    }

    private func markLabel(_ m: String) -> String {
        switch m {
        case "+": return "Mark good"
        case "=": return "Mark neutral"
        case "-": return "Mark poor"
        default: return "Mark \(m)"
        }
    }

    private func categoryRow(face: String, hex: String?, dim: Bool) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(hex.map { Theme.hex($0) } ?? Theme.rule2)
                .frame(width: 8, height: 18)
                .accessibilityHidden(true)
            Text(face)
                .font(.system(size: 20, weight: .semibold))
                .fontWidth(.standard)
                .lineLimit(1)
                .foregroundStyle(dim ? Theme.dim : Theme.fg)
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
