import SwiftUI
import UIKit

struct CaptureView: View {
    @EnvironmentObject private var store: TapStore
    @State private var noteDraft = ""
    @State private var tick = Date()
    @State private var catWidth: CGFloat = 96
    @State private var editingNote = false
    @State private var scrubGroup: String?
    @State private var scrubPick: String?
    @State private var scrubOrigin: String?
    @State private var scrubLocked = false
    @State private var rowTouchAt: Date?
    @State private var colW: CGFloat = 160
    @State private var chipAteTap = false
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
                GeometryReader { geo in
                    let screen = geo.size.width > 1 ? geo.size.width : UIScreen.main.bounds.width
                    let catW = min(max(catWidth + 24, 128), screen * 0.67)
                    HStack(alignment: .top, spacing: 0) {
                        DayRailView(
                            tick: tick,
                            onOpenTap: beginNoteEdit,
                            onOtherTap: finishNoteEdit
                        )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityElement(children: .contain)
                        categoryList(height: geo.size.height)
                            .frame(width: catW)
                            .frame(maxHeight: .infinity)
                    }
                    .background(alignment: .topLeading) { categoryWidthProbe }
                    .onPreferenceChange(CatWidthKey.self) { catWidth = $0 }
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

    @ViewBuilder
    private func categoryList(height: CGFloat) -> some View {
        let n = CGFloat(store.groups.count + 1)
        let rowH = max(44, height / max(n, 1))
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.groups) { group in
                        groupRow(group, rowH: rowH)
                    }
                }
            }
            .scrollDisabled(rowH > 44.5)
            .frame(height: min(rowH * CGFloat(store.groups.count), max(0, height - rowH)))

            sitChip
                .frame(maxWidth: .infinity, minHeight: rowH, maxHeight: rowH)
                .overlay(alignment: .top) { Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1) }
                .id("sit")
        }
        .frame(maxHeight: .infinity)
        .onChange(of: store.scrollToKey) { _, _ in
            store.scrollToKey = nil
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
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

    private func markLabel(_ m: String) -> String {
        switch m {
        case "+": return "Mark good"
        case "=": return "Mark neutral"
        case "-": return "Mark poor"
        default: return "Mark \(m)"
        }
    }

    @ViewBuilder
    private func groupRow(_ group: CategoryGroup, rowH: CGFloat) -> some View {
        let runningChild = store.open.flatMap { open in
            group.children.first { $0.label == open.key }
        }
        let pendingChild = store.pendingKey.flatMap { key in
            group.children.first { $0.label == key }
        }
        let running = runningChild != nil
        let fallback = store.pickFromGroup(group, hover: nil) ?? group.label
        let preview = scrubGroup == group.label ? scrubPick : nil
        let faceLabel = preview ?? pendingChild?.label ?? runningChild?.label ?? fallback
        let faceChild = group.children.first { $0.label == faceLabel }
        let groupWord = group.children.count > 1 ? group.label : nil
        let stopIndex = group.children.firstIndex { $0.label == faceLabel } ?? 0
        let scrubbing = preview != nil
        let pending = pendingChild != nil
        categoryRow(
            face: faceChild?.face ?? group.label,
            group: groupWord,
            hex: faceChild?.hex ?? group.hex,
            dim: false,
            running: running,
            elapsed: elapsedLabel,
            long: running && isLong,
            stops: group.children.count,
            stopIndex: stopIndex,
            scrubbing: scrubbing,
            pending: pending && !scrubbing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            selectedFill(
                hex: faceChild?.hex ?? group.hex,
                on: running || pendingChild != nil || scrubbing,
                heavy: scrubbing
            )
        }
        .frame(height: rowH)
        .overlay(alignment: .top) { Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1) }
        .background {
            GeometryReader { g in
                Color.clear.task(id: g.size.width) { colW = g.size.width }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if rowTouchAt == nil { rowTouchAt = Date() }
                    updateScrub(group, translation: value.translation)
                }
                .onEnded { value in
                    finishRowGesture(group, value: value, rowH: rowH, running: running)
                }
        )
        .accessibilityLabel(groupWord.map { "\($0), \(faceLabel)" } ?? group.label)
        .accessibilityAddTraits((running || pendingChild != nil) ? [.isSelected] : [])
        .accessibilityValue(running ? elapsedLabel : "")
        .accessibilityHint(rowHint(group, running: running, fallback: fallback))
        .accessibilityAction {
            finishNoteEdit()
            if store.open?.key != fallback { store.propose(fallback) }
        }
        .accessibilityActions {
            ForEach(group.children) { child in
                Button(child.label) {
                    finishNoteEdit()
                    if store.open?.key != child.label { store.propose(child.label) }
                }
            }
        }
        .runningCategoryMenu(enabled: running, stop: {
            finishNoteEdit()
            if let key = store.open?.key { store.propose(key) }
        }, split: {
            finishNoteEdit()
            store.openSplit()
        }, addNote: {
            beginNoteEdit()
        })
        .id(group.label)
    }

    private func rowHint(_ group: CategoryGroup, running: Bool, fallback: String) -> String {
        if group.children.count < 2 {
            return running ? "Long press to stop \(fallback)." : "Starts \(fallback)."
        }
        if running {
            let next = store.neighbor(in: group, of: fallback, step: 1)
            return "Swipe to switch child. Long press to stop. Next is \(next)."
        }
        return "Starts \(fallback). Slide to pick a child."
    }

    private func originLabel(for group: CategoryGroup, fallback: String) -> String {
        if let pending = store.pendingKey, group.children.contains(where: { $0.label == pending }) {
            return pending
        }
        if let running = store.open?.key, group.children.contains(where: { $0.label == running }) {
            return running
        }
        return fallback
    }

    private func updateScrub(_ group: CategoryGroup, translation: CGSize) {
        guard group.children.count > 1 else { return }
        let fallback = store.pickFromGroup(group, hover: nil) ?? group.label
        if scrubOrigin == nil {
            scrubOrigin = originLabel(for: group, fallback: fallback)
        }
        let dx = translation.width
        let dy = translation.height
        if !scrubLocked {
            guard abs(dx) >= 14, abs(dx) > 1.5 * abs(dy) else { return }
            scrubLocked = true
        }
        let kids = group.children.map(\.label)
        let origin = kids.firstIndex(of: scrubOrigin ?? fallback) ?? 0
        let n = kids.count
        let raw = origin + Int((dx / 56).rounded())
        let i = ((raw % n) + n) % n
        let pick = kids[i]
        if scrubPick != pick {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        scrubGroup = group.label
        scrubPick = pick
    }

    private func finishRowGesture(
        _ group: CategoryGroup, value: DragGesture.Value, rowH: CGFloat, running: Bool
    ) {
        let dx = value.translation.width
        let dy = value.translation.height
        let kids = group.children.map(\.label)
        let fallback = store.pickFromGroup(group, hover: nil) ?? group.label
        let origin = scrubOrigin ?? originLabel(for: group, fallback: fallback)
        let scrubChanged = scrubLocked && scrubPick != nil && scrubPick != origin
        let onRow = value.location.y >= -32 && value.location.y <= rowH + 32
        let pendingHere = store.pendingKey.map { kids.contains($0) } ?? false
        let inChip = value.location.x >= max(colW, 88) - 100
        let longPress = Date().timeIntervalSince(rowTouchAt ?? Date()) >= 0.5
        defer {
            clearScrub()
            chipAteTap = false
        }
        finishNoteEdit()
        if chipAteTap || (pendingHere && inChip && !scrubChanged) {
            store.cancelPending()
            return
        }
        guard kids.count > 1 else {
            if onRow, !(running && longPress) {
                resolveTap(fallback, pendingHere: pendingHere, inChip: inChip)
            }
            return
        }
        if !onRow && !scrubChanged { return }
        if scrubChanged, let commit = scrubPick {
            if store.open?.key == commit {
                store.cancelPending()
            } else {
                proposeFromRow(commit)
            }
            return
        }
        let isFlick = abs(value.velocity.width) > 700
            && abs(dx) >= 28 && abs(dx) < 56
            && abs(dx) > 1.5 * abs(dy)
        if isFlick {
            proposeFromRow(store.neighbor(in: group, of: origin, step: value.velocity.width < 0 ? 1 : -1))
            return
        }
        if onRow, !(running && longPress) {
            resolveTap(fallback, pendingHere: pendingHere, inChip: inChip)
        }
    }

    private func resolveTap(_ pick: String, pendingHere: Bool, inChip: Bool) {
        if pendingHere, inChip {
            store.cancelPending()
            return
        }
        proposeFromRow(pick)
    }

    private func proposeFromRow(_ key: String) {
        if store.open?.key == key { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        store.proposeFromRow(key)
    }

    private func clearScrub() {
        scrubGroup = nil
        scrubPick = nil
        scrubOrigin = nil
        scrubLocked = false
        rowTouchAt = nil
    }

    private func categoryRow(
        face: String, group: String? = nil, hex: String?, dim: Bool,
        running: Bool = false, elapsed: String = "", long: Bool = false,
        stops: Int = 1, stopIndex: Int = 0, scrubbing: Bool = false,
        pending: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(hex.map { Theme.hex($0) } ?? Theme.rule2)
                .frame(width: 8, height: group == nil ? 18 : 28)
                .accessibilityHidden(true)
            nameStack(
                face: face, group: group, running: running, dim: dim, long: long,
                stops: stops, stopIndex: stopIndex, scrubbing: scrubbing
            )
            if pending || running {
                Spacer(minLength: 4)
                if pending {
                    pendingFuse
                } else {
                    Text(elapsed)
                        .font(Theme.rowFont(12, weight: .bold).monospacedDigit())
                        .foregroundStyle(long ? Theme.flag : Theme.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(0)
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func nameStack(
        face: String, group: String?, running: Bool, dim: Bool, long: Bool,
        stops: Int, stopIndex: Int, scrubbing: Bool
    ) -> some View {
        let child = Text(face)
            .font(Theme.rowFont(20, weight: running ? .bold : .semibold))
            .fontWidth(.standard)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(long ? Theme.flag : (dim ? Theme.dim : Theme.fg))
        if let group {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(group)
                        .font(Theme.rowFont(11, weight: .regular))
                        .tracking(0.4)
                        .foregroundStyle(Theme.dim)
                        .lineLimit(1)
                    if stops > 1 {
                        childDots(stops: stops, stopIndex: stopIndex, lit: scrubbing)
                    }
                }
                child
            }
        } else {
            child
        }
    }

    @ViewBuilder
    private var pendingFuse: some View {
        let n = store.undoSecondsLeft
        let body = Text("CANCEL · \(n)")
            .font(Theme.rowFont(12, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(Theme.fg)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(minWidth: 72, minHeight: 44, alignment: .trailing)
            .contentShape(Rectangle())
        Button {
            chipAteTap = true
            store.cancelPending()
        } label: {
            body
        }
        .buttonStyle(.plain)
        .highPriorityGesture(
            TapGesture().onEnded {
                chipAteTap = true
                store.cancelPending()
            }
        )
        .accessibilityLabel("Cancel: \(store.undoLabel ?? "")")
        .accessibilityHint("Available for \(n) seconds")
    }

    private func childDots(stops: Int, stopIndex: Int, lit: Bool) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<stops, id: \.self) { i in
                let on = i == stopIndex
                Circle()
                    .fill(on ? Theme.fg : Theme.dim.opacity(0.45))
                    .frame(width: on && lit ? 8 : 6, height: on && lit ? 8 : 6)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func selectedFill(hex: String?, on: Bool, heavy: Bool = false) -> some View {
        if on {
            Theme.panel.overlay(hex.map { Theme.hex($0).opacity(heavy ? 0.20 : 0.15) } ?? Color.clear)
        } else {
            Color.clear
        }
    }

    private var categoryWidthProbe: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.groups) { group in
                categoryRow(face: group.label, hex: group.hex, dim: false)
                    .fixedSize()
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(key: CatWidthKey.self, value: g.size.width)
                        }
                    )
                ForEach(group.children) { cat in
                    categoryRow(
                        face: cat.face,
                        group: group.children.count > 1 ? group.label : nil,
                        hex: cat.hex, dim: false,
                        running: true, elapsed: "12h00", long: false,
                        stops: group.children.count,
                        stopIndex: 0
                    )
                    .fixedSize()
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(key: CatWidthKey.self, value: g.size.width)
                        }
                    )
                }
            }
        }
        .fixedSize()
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}

private extension View {
    @ViewBuilder
    func runningCategoryMenu(
        enabled: Bool,
        stop: @escaping () -> Void,
        split: @escaping () -> Void,
        addNote: @escaping () -> Void
    ) -> some View {
        if enabled {
            self
                .contextMenu {
                    Button("Stop", action: stop)
                    Button("Split", action: split)
                    Button("Add note", action: addNote)
                }
                .accessibilityAction(named: "Stop", stop)
                .accessibilityAction(named: "Split", split)
                .accessibilityAction(named: "Add note", addNote)
                .accessibilityHint("Does not stop sitting. Long press for stop, split, and add note.")
        } else {
            self
        }
    }
}

private struct CatWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
