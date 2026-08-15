import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class TapStore: ObservableObject {
    @Published var config: ClientConfig?
    @Published var open: OpenBlock?
    @Published var sit: SitBlock?
    /// Start of the current not-sitting bout. Feeds the Live Activity standing timer.
    var standStartMs: Double?
    @Published var today: [TodayBlock] = []
    @Published var planToday: [TodayBlock] = []
    @Published var distracted = false
    @Published var queue: [Op] = []
    @Published var dead: [DeadEntry] = []
    @Published var syncLabel = "synced"
    @Published var syncFailed = false
    @Published var banner: String?
    @Published var showSettings = false
    @Published var showSignIn = false
    @Published var showPicker = false
    @Published var showDead = false
    @Published var addingCategory = false
    /// False until `bootAsync` finishes. Tests that pin `testHasSession` start ready.
    var sessionReady = false
    var lastInsertFailed = false

    @Published var undoLabel: String?
    @Published var undoSecondsLeft: Int = 0
    @Published var pendingKey: String?
    @Published var pendingStop = false
    @Published var markStrip: MarkStrip?

    @Published var split: SplitState?
    @Published var sitEdit: SitEditState?
    @Published var scrollToKey: String?
    @Published var unreadableOpen = false

    struct MarkStrip: Equatable {
        var ref: String
        var key: String
        var durMs: Double
        var hintMs: Double
    }

    struct SplitState: Equatable {
        var ref: String
        var startMs: Double
        var nowMs: Double
        var atMs: Double
        var whole: Bool
    }

    struct SitEditState: Equatable {
        var lo: Double
        var hi: Double
        var atMs: Double
    }

    struct RailItem: Identifiable {
        var id: String
        var name: String
        var ms: Double
        var hex: String?
        var isGap: Bool
        var isOpen: Bool
        var height: CGFloat
        var note: String = ""
    }

    private struct UndoOffer {
        var prev: OpenBlock?
        var newRef: String?
        var atMs: Double
        var closeId: String?
        var openId: String?
        var sit: ClosedSit?
        var label: String
        var until: Date
    }

    private struct ClosedSit {
        var ref: String
        var startMs: Double
        var closeId: String?
    }

    private struct BlockMeta: Codable {
        var key: String?
        var startMs: Double?
    }

    private var undo: UndoOffer?
    private var undoTimer: Timer?
    private var pendingUntil: Date?
    private var pendingTimer: Timer?
    private var markTimer: Timer?
    private var noteTask: Task<Void, Never>?
    private var flushTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var flushing = false
    private var localGen = 0
    private var lastStateAt = Date()
    private(set) var retryDelay: TimeInterval = 4
    var clock: () -> Double = { Date().timeIntervalSince1970 * 1000 }
    var noteDelayNs: UInt64 = 900_000_000
    private var lastTapMs: Double = 0
    private var transportFails = 0
    private var stateAfterBootDrain = false
    private var stateAfterCorrectiveDrain = false
    private var persistBroken = false
    private var catByKey: [String: Category] = [:]
    private var blocks: [String: BlockMeta] = [:]
    private var distractStartMs: Double?
    private var distractedAccruedMs: Double = 0

    private let queueKey = "tt.queue.v1"
    private let stateKey = "tt.state.v1"
    private let deadKey = "tt.dead.v1"
    private let blocksKey = "tt.blocks.v1"
    private let configKey = "tt.config.v1"
    private let msMin: Double = 60_000
    private let gapMs: Double = 90_000

    init() {
        loadPersisted()
        // Production restore is async. Flashing Sign-In before it is the bug.
        // Tests pin testHasSession, so they can decide now.
        guard GoogleAuth.testHasSession != nil else { return }
        sessionReady = true
        if !GoogleAuth.hasSession {
            showSignIn = true
        } else if !Credentials.hasCalendarIds {
            showPicker = true
        }
    }

    func signOut() {
        flushTask?.cancel()
        retryTask?.cancel()
        flushTask = nil
        retryTask = nil
        flushing = false
        GoogleAuth.signOut()
        showSignIn = true
        showSettings = false
        showPicker = false
        paintSync()
        Task { await RunningBlockSync.apply(nil) }
    }

    func boot() { Task { await bootAsync() } }

    func refreshOnReturn() {
        Task { await refreshOnReturnNow() }
    }

    func refreshOnReturnNow() async {
        defer { syncLiveActivity() }
        guard Credentials.isConfigured, config != nil else { return }
        if !queue.isEmpty {
            await flushNow()
            return
        }
        let overdue = Date().timeIntervalSince(lastStateAt) > 10 * 60
        let runaway = open.map {
            Date().timeIntervalSince1970 * 1000 - $0.startMs
                > Double(config?.staleOpenHours ?? 5) * 3_600_000
        } ?? false
        if overdue || runaway { await loadServerState() }
    }

    // MARK: - Capture actions

    /// Gesture proposes a start, switch, or stop. Calendar write waits 5s.
    func propose(_ key: String) {
        let key = Grammar.resolve(key)
        if !sessionReady { return }
        guard GoogleAuth.hasSession else {
            showSignIn = true
            return
        }
        if Credentials.actualId.isEmpty {
            banner = "Pick PLAN, ACTUAL and SITTING calendars first."
            showPicker = true
            return
        }
        if let open, open.key == key, lastInsertFailed {
            tapCategory(key)
            return
        }
        pendingKey = key
        pendingStop = open?.key == key
        armPending()
    }

    /// Row tap. Same leaf stays running; the long-press menu owns Stop.
    func proposeFromRow(_ key: String) {
        if open?.key == key { return }
        propose(key)
    }

    func cancelPending() {
        clearPending()
    }

    func commitPending() {
        let key = pendingKey
        let stop = pendingStop
        clearPending()
        lastTapMs = 0
        if stop {
            endDay()
        } else if let key {
            tapCategory(key)
        }
    }

    func tapCategory(_ key: String) {
        clearPending()
        let key = Grammar.resolve(key)
        if !sessionReady { return }
        guard GoogleAuth.hasSession else {
            showSignIn = true
            return
        }
        if Credentials.actualId.isEmpty {
            banner = "Pick PLAN, ACTUAL and SITTING calendars first."
            showPicker = true
            return
        }
        let now = clock()
        if let open, open.key == key, lastInsertFailed {
            lastTapMs = now
            retryLastInsert()
            return
        }
        if now - lastTapMs < 300 { return }
        lastTapMs = now
        if let open, open.key == key {
            // Same-key tap stops. Split is a long press on the running row.
            endDay()
            return
        }

        closeBlockSheets()

        var pending: MarkStrip?
        if let cur = open {
            let dur = now - cur.startMs
            let m = markFor(key: cur.key, durMs: dur)
            let d = takeDistractedMs()
            _ = enqueue(Op(
                id: Op.uid(), type: "closeActual", ts: now,
                ref: cur.ref, key: cur.key, text: cur.text, mark: m.mark, endMs: now,
                distractedMs: d
            ))
            if m.strip {
                pending = MarkStrip(ref: cur.ref, key: cur.key, durMs: dur, hintMs: cur.startMs)
            }
            railClosed(cur, endMs: now, distractedMs: d)
        }

        let ref = Op.uid()
        open = OpenBlock(ref: ref, key: key, startMs: now)
        _ = enqueue(Op(
            id: Op.uid(), type: "openActual", ts: now,
            ref: ref, key: key, startMs: now
        ))

        if let pending { showMarkStrip(pending) } else { hideMarkStrip() }
        unreadableOpen = false
        scrollToKey = key
        if let g = group(containing: key) { lastUsed[g.label] = key }
        persist()
        if CalendarAPI.testCalendar != nil {
            do {
                _ = try CalendarAPI.openActual(key: key, at: now, ref: ref)
                lastInsertFailed = false
            } catch {
                lastInsertFailed = true
            }
        }
        if !lastInsertFailed { flush() }
        paintSync()
        syncLiveActivity()
    }

    func retryLastInsert() {
        do {
            try CalendarAPI.retryLastInsert()
            lastInsertFailed = false
        } catch {
            lastInsertFailed = true
        }
        paintSync()
    }

    func endDay() {
        clearPending()
        let now = clock()
        closeBlockSheets()
        var pending: MarkStrip?
        var didStop = false

        if let cur = open {
            didStop = true
            let dur = now - cur.startMs
            let m = markFor(key: cur.key, durMs: dur)
            let d = takeDistractedMs()
            _ = enqueue(Op(
                id: Op.uid(), type: "closeActual", ts: now,
                ref: cur.ref, key: cur.key, text: cur.text, mark: m.mark, endMs: now,
                distractedMs: d
            ))
            railClosed(cur, endMs: now, distractedMs: d)
            pending = m.strip
                ? MarkStrip(ref: cur.ref, key: cur.key, durMs: dur, hintMs: cur.startMs)
                : nil
            open = nil
            if let pending { showMarkStrip(pending) } else { hideMarkStrip() }
        }

        if didStop {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        unreadableOpen = false
        persist()
        flush()
        syncLiveActivity()
    }

    func toggleDistract() {
        guard open != nil else { return }
        if distracted {
            if let start = distractStartMs {
                distractedAccruedMs += clock() - start
            }
            distractStartMs = nil
            distracted = false
        } else {
            distractStartMs = clock()
            distracted = true
        }
        persist()
    }

    func currentDistractedMs() -> Double {
        var ms = distractedAccruedMs
        if distracted, let start = distractStartMs {
            ms += clock() - start
        }
        return ms
    }

    private func takeDistractedMs() -> Double {
        let d = currentDistractedMs()
        distracted = false
        distractedAccruedMs = 0
        distractStartMs = nil
        return d
    }

    func toggleSit() {
        if !sessionReady { return }
        guard GoogleAuth.hasSession else {
            showSignIn = true
            return
        }
        let now = clock()
        if now - lastTapMs < 300 { return }
        lastTapMs = now
        if sit != nil {
            _ = closeSit(at: now)
        } else {
            let ref = Op.uid()
            sit = SitBlock(ref: ref, startMs: now)
            _ = enqueue(Op(id: Op.uid(), type: "openSit", ts: now, ref: ref, startMs: now))
        }
        persist()
        flush()
        syncLiveActivity()
    }

    func stopSit() {
        if !sessionReady { return }
        guard GoogleAuth.hasSession else {
            showSignIn = true
            return
        }
        guard sit != nil else { return }
        let now = clock()
        if now - lastTapMs < 300 { return }
        lastTapMs = now
        _ = closeSit(at: now)
        persist()
        flush()
        syncLiveActivity()
    }

    func handleSitIntent() async {
        await ensureIntentSession()
        toggleSit()
        await flushNow()
    }

    func handleStopSitIntent() async {
        await ensureIntentSession()
        stopSit()
        await flushNow()
    }

    func handleStopIntent() async {
        await ensureIntentSession()
        endDay()
        await flushNow()
    }

    /// Live Activity intents can start a killed app in the background. Restore Google first.
    private func ensureIntentSession() async {
        if GoogleAuth.testHasSession != nil { return }
        if !GoogleAuth.hasSession {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                GoogleAuth.restore { cont.resume() }
            }
        }
        if !sessionReady {
            await bootNow()
        }
    }

    func takeUndo() {
        if pendingKey != nil {
            clearPending()
            return
        }
        guard let u = undo else { return }
        clearUndo()
        let now = clock()

        let newSit: SitBlock? = {
            guard let closed = u.sit, let cur = sit, cur.ref != closed.ref else { return nil }
            return cur
        }()
        let newSitOpenId = newSit.flatMap { pendingOpenSit($0.ref) }
        var ids: [String?] = [u.closeId, u.openId]
        if let s = u.sit { ids.append(s.closeId) }
        if let id = newSitOpenId { ids.append(id) }

        let droppable = newSit == nil || newSitOpenId != nil
        if !droppable || !dropOps(ids.compactMap { $0 }) {
            _ = enqueue(Op(
                id: Op.uid(), type: "undoSwitch", ts: now,
                atMs: u.atMs, nowMs: now, newRef: u.newRef,
                prevRef: u.prev?.ref, prevKey: u.prev?.key,
                prevText: u.prev?.text, prevStartMs: u.prev?.startMs,
                sitRef: u.sit?.ref, sitStartMs: u.sit?.startMs,
                killSitRef: newSit?.ref
            ))
        }

        if let prev = u.prev {
            queue = queue.filter { !($0.type == "setMark" && $0.ref == prev.ref) }
            saveQueue()
            railReopen(prev.ref)
        }
        open = u.prev
        if let s = u.sit {
            sit = SitBlock(ref: s.ref, startMs: s.startMs)
        }
        hideMarkStrip()
        refreshUnreadable()
        persist()
        flush()
        syncLiveActivity()
    }

    func applyMark(_ mark: String) {
        guard let strip = markStrip else { return }
        hideMarkStrip()
        if mark != "=" {
            _ = enqueue(Op(
                id: Op.uid(), type: "setMark",
                ts: clock(),
                ref: strip.ref, mark: mark, hintMs: strip.hintMs
            ))
            flush()
        }
    }

    func noteChanged(_ text: String) {
        guard var cur = open else { return }
        cur.text = text
        open = cur
        persist()
        let ref = cur.ref
        let hint = cur.startMs
        queue = queue.filter { !($0.type == "setText" && $0.ref == ref) }
        _ = enqueue(Op(
            id: Op.uid(), type: "setText",
            ts: clock(),
            ref: ref, text: text, hintMs: hint
        ))
        noteTask?.cancel()
        noteTask = Task {
            try? await Task.sleep(nanoseconds: noteDelayNs)
            guard !Task.isCancelled else { return }
            flush()
        }
    }

    // MARK: - Split

    func openSplit() {
        guard let cur = open else { return }
        clearUndo()
        let now = clock()
        let span = max(1, Int(((now - cur.startMs) / msMin).rounded()))
        if span < 2 {
            split = SplitState(
                ref: cur.ref, startMs: cur.startMs, nowMs: now,
                atMs: now, whole: true
            )
            return
        }
        let mid = max(1, span / 2)
        split = SplitState(
            ref: cur.ref,
            startMs: cur.startMs,
            nowMs: now,
            atMs: cur.startMs + Double(mid) * msMin,
            whole: false
        )
    }

    /// Slider 1...1 crashes. A block shorter than two minutes still gets 1...2.
    static func splitSliderRange(startMs: Double, nowMs: Double) -> ClosedRange<Double> {
        let span = max(1, Int(((nowMs - startMs) / 60_000).rounded()))
        return 1...Double(max(span - 1, 2))
    }

    func setSplitWhole(_ whole: Bool) {
        guard var s = split else { return }
        s.whole = whole
        split = s
    }

    func setSplitMinutes(_ mins: Int) {
        guard var s = split else { return }
        s.atMs = s.startMs + Double(max(1, mins)) * msMin
        split = s
    }

    func doSplit(key: String) {
        let key = Grammar.resolve(key)
        guard let s = split, let cur = open, cur.ref == s.ref else {
            split = nil
            return
        }
        if s.whole {
            recatWhole(key: key)
            return
        }
        let now = clock()
        let at = min(s.atMs, now - msMin)
        if at <= cur.startMs {
            recatWhole(key: key)
            return
        }
        let m = markFor(key: cur.key, durMs: at - cur.startMs)
        let newRef = Op.uid()
        _ = enqueue(Op(
            id: Op.uid(), type: "splitActual", ts: now,
            ref: cur.ref, text: cur.text, mark: m.mark,
            atMs: at, nowMs: now, newRef: newRef, newKey: key
        ))
        railClosed(cur, endMs: at)
        open = OpenBlock(ref: newRef, key: key, startMs: at)
        hideMarkStrip()
        split = nil
        persist()
        flush()
        syncLiveActivity()
    }

    private func recatWhole(key: String) {
        guard var cur = open else { return }
        if cur.key != key {
            cur.key = key
            open = cur
            if !mutatePendingOpen(ref: cur.ref, key: key) {
                _ = enqueue(Op(
                    id: Op.uid(), type: "recategorize",
                    ts: clock(),
                    ref: cur.ref, key: key, hintMs: cur.startMs
                ))
            }
        }
        hideMarkStrip()
        split = nil
        persist()
        flush()
        syncLiveActivity()
    }

    // MARK: - Sit edit

    func openSitEdit() {
        guard let cur = sit else { return }
        let now = clock()
        let lo = min(cur.startMs, now - 6 * 3_600_000)
        sitEdit = SitEditState(lo: lo, hi: now, atMs: cur.startMs)
    }

    func setSitEditMinutes(_ mins: Int) {
        guard var s = sitEdit else { return }
        s.atMs = min(s.lo + Double(mins) * msMin, s.hi - msMin)
        sitEdit = s
    }

    func applySitEdit() {
        guard let s = sitEdit, var cur = sit else { return }
        cur.startMs = s.atMs
        sit = cur
        _ = enqueue(Op(
            id: Op.uid(), type: "setSitStart",
            ts: clock(),
            ref: cur.ref, startMs: s.atMs
        ))
        sitEdit = nil
        persist()
        flush()
        syncLiveActivity()
    }

    func deleteSit() {
        guard let cur = sit else { return }
        _ = enqueue(Op(
            id: Op.uid(), type: "deleteSit",
            ts: clock(),
            ref: cur.ref, hintMs: cur.startMs
        ))
        sit = nil
        standStartMs = clock()
        sitEdit = nil
        persist()
        flush()
        syncLiveActivity()
    }

    // MARK: - Dead letter

    func openDeadDrawer() {
        guard !dead.isEmpty else { return }
        showDead = true
    }

    func discardDead(token: String) {
        dead.removeAll { $0.token == token }
        saveDead()
        if dead.isEmpty {
            showDead = false
            banner = nil
            syncFailed = false
        } else {
            banner = deadMsg()
            syncFailed = true
        }
        paintSync()
    }

    // MARK: - Rail

    func railItems(budget: CGFloat, now: Double) -> (startLabel: String, items: [RailItem]) {
        railItems(source: .actual, budget: budget, now: now)
    }

    func railItems(source: RailSource, budget: CGFloat, now: Double) -> (startLabel: String, items: [RailItem]) {
        let dayStart = Format.dayStartMs(now)
        let windowEnd = max(
            now,
            planToday.map(\.endMs).max() ?? now,
            today.map(\.endMs).max() ?? now
        )
        let span = max(windowEnd - dayStart, 60_000)

        var blocks: [TodayBlock]
        switch source {
        case .plan:
            blocks = planToday.filter { $0.endMs > dayStart }
        case .actual:
            blocks = today.filter { $0.endMs > dayStart }
            if let open {
                blocks.append(TodayBlock(
                    ref: open.ref, key: open.key, startMs: open.startMs, endMs: now, text: open.text
                ))
            }
        }
        blocks.sort { $0.startMs < $1.startMs }

        let gapName = source == .actual ? "UNLOGGED" : "—"
        var raw: [(name: String, ms: Double, hex: String?, gap: Bool, open: Bool, note: String)] = []
        var prevEnd = dayStart
        if blocks.isEmpty {
            raw.append((gapName, max(now - dayStart, 1), nil, true, false, ""))
            prevEnd = now
        } else {
            for b in blocks {
                let start = max(b.startMs, dayStart)
                if start - prevEnd > gapMs {
                    raw.append((gapName, start - prevEnd, nil, true, false, ""))
                }
                let id = Grammar.resolve(b.key)
                let cat = catByKey[id]
                let ms = b.endMs - start
                let isOpen = source == .actual && (open.map { o in
                    (b.ref != nil && b.ref == o.ref) || (b.ref == nil && b.startMs == o.startMs && b.endMs == now)
                } ?? false)
                raw.append((
                    (cat?.face ?? id).uppercased(),
                    ms,
                    cat?.hex,
                    false,
                    isOpen,
                    b.text
                ))
                prevEnd = max(prevEnd, b.endMs)
            }
        }
        if source == .actual, open == nil, now - prevEnd > 5000 {
            raw.append(("UNLOGGED", now - prevEnd, nil, true, false, ""))
        } else if source == .plan, now - prevEnd > 5000 {
            raw.append(("—", now - prevEnd, nil, true, false, ""))
        }

        let px = budget / span
        let items = raw.enumerated().map { idx, r in
            RailItem(
                id: "\(idx)",
                name: r.name, ms: r.ms, hex: r.hex,
                isGap: r.gap, isOpen: r.open, height: max(CGFloat(r.ms) * px, 1),
                note: r.note
            )
        }
        let labelStart = blocks.isEmpty ? dayStart : max(blocks[0].startMs, dayStart)
        let prefix = source == .plan ? "PLAN" : "ACTUAL"
        return ("\(prefix) · \(Format.clock(labelStart))", items)
    }

    func labelFor(_ key: String) -> String { catByKey[Grammar.resolve(key)]?.face ?? Grammar.resolve(key) }
    func colorFor(_ key: String) -> Color { Theme.hex(catByKey[Grammar.resolve(key)]?.hex ?? "#616161") }
    var categories: [Category] { config?.categories ?? [] }
    var groups: [CategoryGroup] { config?.groups ?? [] }
    var lastUsed: [String: String] = [:]
    var deadCount: Int { dead.count }
    var canAddCategory: Bool {
        groups.count < (config?.maxGroups ?? TT.maxGroups)
            && categories.count < (config?.maxCategories ?? TT.maxCategories)
    }

    func group(containing label: String) -> CategoryGroup? {
        let want = Grammar.resolve(label)
        return groups.first { $0.children.contains { $0.label == want } }
    }

    func pickFromGroup(_ group: CategoryGroup, hover: String?) -> String? {
        if let hover, group.children.contains(where: { $0.label == hover }) { return hover }
        if let used = lastUsed[group.label], group.children.contains(where: { $0.label == used }) {
            return used
        }
        return group.children.first?.label
    }

    func arm(_ group: CategoryGroup, child: String) {
        guard group.children.contains(where: { $0.label == child }) else { return }
        lastUsed[group.label] = child
        objectWillChange.send()
        persist()
    }

    func neighbor(in group: CategoryGroup, of label: String, step: Int) -> String {
        let kids = group.children.map(\.label)
        guard let i = kids.firstIndex(of: label), !kids.isEmpty else {
            return kids.first ?? label
        }
        let n = kids.count
        return kids[(i + step % n + n) % n]
    }

    func addCategory(label: String, onSuccess: (() -> Void)? = nil) {
        addGroup(label: label, onSuccess: onSuccess)
    }

    func addGroup(label: String, onSuccess: (() -> Void)? = nil) {
        guard let clipped = cleanName(label) else { return }
        var cfg = config ?? .seed
        if cfg.groups.count >= cfg.maxGroups {
            banner = "That is \(cfg.maxGroups) groups already."
            return
        }
        if cfg.categories.count >= cfg.maxCategories {
            banner = "That is \(cfg.maxCategories) categories already."
            return
        }
        if cfg.groups.contains(where: { $0.label.lowercased() == clipped.lowercased() }) {
            banner = "There is already a group called \(clipped)."
            return
        }
        if let hit = cfg.categories.first(where: { $0.label.lowercased() == clipped.lowercased() }) {
            banner = "There is already a category called \(hit.label)."
            return
        }
        let color = Grammar.nextColor(cfg.categories)
        let hex = TT.colorHex[color] ?? "#616161"
        let child = Category(label: clipped, color: color, hex: hex)
        cfg.retired.removeAll { $0.lowercased() == clipped.lowercased() }
        cfg.groups.append(CategoryGroup(label: clipped, color: color, hex: hex, children: [child]))
        applyConfig(cfg)
        addingCategory = false
        banner = nil
        onSuccess?()
    }

    func addChild(group: String, label: String) {
        guard let clipped = cleanName(label) else { return }
        var cfg = config ?? .seed
        guard let gi = cfg.groups.firstIndex(where: { $0.label == group }) else { return }
        if cfg.groups[gi].children.count >= TT.maxChildrenPerGroup {
            banner = "That is \(TT.maxChildrenPerGroup) in \(group) already."
            return
        }
        if cfg.categories.count >= cfg.maxCategories {
            banner = "That is \(cfg.maxCategories) categories already."
            return
        }
        if let hit = cfg.categories.first(where: { $0.label.lowercased() == clipped.lowercased() }) {
            banner = "There is already a category called \(hit.label)."
            return
        }
        let g = cfg.groups[gi]
        let child = Category(label: clipped, color: g.color, hex: g.hex, autoMark: g.autoMark)
        cfg.retired.removeAll { $0.lowercased() == clipped.lowercased() }
        cfg.groups[gi].children.append(child)
        applyConfig(cfg)
        banner = nil
    }

    func renameGroup(from: String, to: String) {
        guard let clipped = cleanName(to) else { return }
        var cfg = config ?? .seed
        guard let gi = cfg.groups.firstIndex(where: { $0.label == from }) else { return }
        if cfg.groups.contains(where: {
            $0.label.lowercased() == clipped.lowercased() && $0.label != from
        }) {
            banner = "There is already a group called \(clipped)."
            return
        }
        cfg.groups[gi].label = clipped
        if let used = lastUsed[from] {
            lastUsed[clipped] = used
            lastUsed.removeValue(forKey: from)
        }
        applyConfig(cfg)
        persist()
        banner = nil
    }

    func renameChild(from: String, to: String) {
        guard let clipped = cleanName(to) else { return }
        var cfg = config ?? .seed
        if let hit = cfg.categories.first(where: {
            $0.label.lowercased() == clipped.lowercased() && $0.label != from
        }) {
            banner = "There is already a category called \(hit.label)."
            return
        }
        for gi in cfg.groups.indices {
            guard let ci = cfg.groups[gi].children.firstIndex(where: { $0.label == from }) else { continue }
            cfg.groups[gi].children[ci].label = clipped
            if open?.key == from { open?.key = clipped }
            lastUsed = lastUsed.mapValues { $0 == from ? clipped : $0 }
            applyConfig(cfg)
            persist()
            banner = nil
            return
        }
    }

    func deleteGroup(_ label: String) {
        var cfg = config ?? .seed
        guard let gi = cfg.groups.firstIndex(where: { $0.label == label }) else { return }
        if cfg.groups.count <= 1 {
            banner = "Keep at least one group."
            return
        }
        let kids = cfg.groups[gi].children
        if let open, kids.contains(where: { $0.label == open.key }) {
            banner = "Stop that block first."
            return
        }
        for kid in kids where !cfg.retired.contains(where: { $0.lowercased() == kid.label.lowercased() }) {
            cfg.retired.append(kid.label)
        }
        cfg.groups.remove(at: gi)
        lastUsed.removeValue(forKey: label)
        applyConfig(cfg)
        persist()
        banner = nil
    }

    func deleteChild(_ label: String) {
        var cfg = config ?? .seed
        for gi in cfg.groups.indices {
            guard let ci = cfg.groups[gi].children.firstIndex(where: { $0.label == label }) else { continue }
            if cfg.groups[gi].children.count <= 1 {
                banner = "Delete the group instead."
                return
            }
            if open?.key == label {
                banner = "Stop that block first."
                return
            }
            if !cfg.retired.contains(where: { $0.lowercased() == label.lowercased() }) {
                cfg.retired.append(label)
            }
            cfg.groups[gi].children.remove(at: ci)
            lastUsed = lastUsed.filter { $0.value != label }
            applyConfig(cfg)
            persist()
            banner = nil
            return
        }
    }

    private func cleanName(_ label: String) -> String? {
        let name = String(label)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = String(name.prefix(24))
        if clipped.isEmpty {
            banner = "A category needs a name."
            return nil
        }
        if clipped.contains(":") {
            banner = "A category name cannot contain a colon."
            return nil
        }
        if clipped.uppercased() == "UNLOGGED" || clipped.uppercased() == TT.unfiledKey {
            banner = "\(clipped) is reserved."
            return nil
        }
        return clipped
    }

    private func refreshUnreadable() {
        guard config != nil, !catByKey.isEmpty else { return }
        let bad = open.map { catByKey[$0.key] == nil } ?? false
        if bad {
            let name = open?.text.isEmpty == false ? open!.text : (open?.key ?? "")
            banner = "a block is running that this app cannot read: \(name). Tap any category to close it, or fix its title in Google Calendar."
            unreadableOpen = true
        } else if unreadableOpen {
            unreadableOpen = false
            if dead.isEmpty { banner = nil }
            else { banner = deadMsg() }
        }
    }

    // MARK: - Boot / network

    func didSignIn() async {
        showSignIn = false
        if Credentials.hasCalendarIds {
            await bootNow()
        } else {
            showPicker = true
        }
    }

    func didConfirmCalendars() async {
        showPicker = false
        await bootNow()
    }

    func confirmCalendars(plan: String?, actual: String?, sitting: String?) async {
        guard CalendarAPI.canConfirm(plan: plan, actual: actual, sitting: sitting) else { return }
        let newA = actual ?? ""
        let newS = sitting ?? ""
        let switching = Credentials.hasCalendarIds
            && (Credentials.actualId != newA || Credentials.sittingId != newS)
        if switching {
            if open != nil || sit != nil {
                closeRunningOnCurrentCalendars()
            }
            if !queue.isEmpty {
                await flushNow()
            }
        }
        guard CalendarAPI.confirm(plan: plan, actual: actual, sitting: sitting) else { return }
        await didConfirmCalendars()
    }

    func loadCalendars() async -> Result<[CalendarSummary], Error> {
        var didRefresh = false
        while true {
            do {
                return .success(try await CalendarAPI.listCalendars())
            } catch let http as CalendarHTTPError where http.status == 401 {
                if didRefresh {
                    showSignIn = true
                    return .failure(http)
                }
                try? await GoogleAuth.refreshAccessToken()
                didRefresh = true
            } catch {
                return .failure(error)
            }
        }
    }

    private func closeRunningOnCurrentCalendars() {
        let now = clock()
        closeBlockSheets()
        if let cur = open {
            let m = markFor(key: cur.key, durMs: now - cur.startMs)
            _ = enqueue(Op(
                id: Op.uid(), type: "closeActual", ts: now,
                ref: cur.ref, key: cur.key, text: cur.text, mark: m.mark, endMs: now
            ))
            railClosed(cur, endMs: now)
            open = nil
            hideMarkStrip()
        }
        _ = closeSit(at: now)
        persist()
        syncLiveActivity()
    }

    private func bootAsync() async {
        defer { sessionReady = true }
        if persistBroken { return }
        if !GoogleAuth.hasSession {
            showSignIn = true
            return
        }
        showSignIn = false
        guard Credentials.hasCalendarIds else {
            showPicker = true
            return
        }
        if queue.isEmpty {
            await loadServerState()
        } else {
            stateAfterBootDrain = true
            await flushAsync()
        }
    }

    private func applyConfig(_ cfg: ClientConfig, write: Bool = true) {
        let cfg = Self.normalize(cfg)
        config = cfg
        catByKey = Dictionary(cfg.categories.map { ($0.label, $0) }, uniquingKeysWith: { _, n in n })
        Grammar.knownLabels = cfg.categories.map(\.label) + cfg.retired
        Grammar.extraColors = [:]
        for c in cfg.categories where TT.colorIdByLabel[c.label] == nil && !c.color.isEmpty {
            Grammar.extraColors[c.label] = c.color
        }
        if write, let data = try? JSONEncoder().encode(cfg) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
        refreshUnreadable()
    }

    private func loadServerState(corrective: Bool = false) async {
        let gen = localGen
        var didRefresh = false
        while true {
            do {
                let st = try await CalendarAPI.refreshState()
                if adoptServerState(st, gen: gen) {
                    lastStateAt = Date()
                    if CalendarAPI.didStaleClose, !unreadableOpen {
                        banner = "an overnight block was closed with a guess. Check the calendar."
                    }
                    CalendarAPI.didStaleClose = false
                } else if corrective {
                    await loadCorrectiveState()
                }
                return
            } catch let http as CalendarHTTPError where http.status == 401 {
                if didRefresh {
                    showSignIn = true
                    banner = http.localizedDescription
                    return
                }
                try? await GoogleAuth.refreshAccessToken()
                didRefresh = true
            } catch {
                banner = error.localizedDescription
                return
            }
        }
    }

    private func adoptServerState(_ st: ServerState, gen: Int) -> Bool {
        if gen != localGen || !queue.isEmpty { return false }
        let wasRef = open?.ref
        let wasSit = sit?.ref
        open = st.open
        sit = st.sit
        today = st.today ?? []
        planToday = st.planToday ?? []
        if wasRef != open?.ref || wasSit != sit?.ref {
            closeBlockSheets()
        }
        persist()
        refreshUnreadable()
        syncLiveActivity()
        return true
    }

    private func loadCorrectiveState() async {
        if flushing || !queue.isEmpty {
            stateAfterCorrectiveDrain = true
            return
        }
        stateAfterCorrectiveDrain = false
        await loadServerState(corrective: true)
    }

    func flush() {
        guard flushTask == nil, !flushing else { return }
        flushTask = Task { [weak self] in
            await self?.flushAsync()
            self?.flushTask = nil
        }
    }

    func flushNow() async {
        retryTask?.cancel()
        retryTask = nil
        if let t = flushTask { await t.value }
        flushTask = nil
        await flushAsync()
    }

    func bootNow() async { await bootAsync() }

    private func flushAsync() async {
        guard !flushing, Credentials.isConfigured else { return }
        let batch = Array(queue.prefix(40))
        guard !batch.isEmpty else {
            paintSync()
            if stateAfterBootDrain {
                stateAfterBootDrain = false
                await loadServerState()
            }
            if stateAfterCorrectiveDrain {
                await loadCorrectiveState()
            }
            return
        }
        flushing = true
        paintSync()

        var didRefresh = false
        while true {
            do {
                let result = try await CalendarAPI.flushOps(batch)
                let done = Set(result.applied ?? [])
                queue.removeAll { done.contains($0.id) }
                saveQueue()
                lastInsertFailed = false
                transportFails = 0
                flushing = false
                if batch.contains(where: { $0.type == "undoSwitch" && done.contains($0.id) }) {
                    await loadCorrectiveState()
                }
                if let err = result.errors?.first {
                    quarantine(err)
                    scheduleRetry()
                } else {
                    retryDelay = 4
                    if !queue.isEmpty {
                        await flushAsync()
                    } else {
                        if stateAfterBootDrain {
                            stateAfterBootDrain = false
                            await loadServerState()
                        }
                        if stateAfterCorrectiveDrain {
                            await loadCorrectiveState()
                        }
                    }
                }
                paintSync()
                return
            } catch let http as CalendarHTTPError {
                if http.status == 401 {
                    if didRefresh {
                        flushing = false
                        showSignIn = true
                        paintSync()
                        return
                    }
                    try? await GoogleAuth.refreshAccessToken()
                    didRefresh = true
                    continue
                }
                flushing = false
                if http.status == 429, let ra = http.retryAfter {
                    retryDelay = max(retryDelay, ra)
                }
                if http.status == 429 || http.status >= 500 {
                    transportFails += 1
                    banner = "Google Calendar is unreachable. The running block is still here."
                    if transportFails < 5 { scheduleRetry() }
                    paintSync()
                    return
                }
                if http.status >= 400 {
                    if batch.count == 1, let id = batch.first?.id {
                        quarantine(.init(id: id, message: http.localizedDescription))
                    } else {
                        banner = http.localizedDescription
                    }
                }
                if !queue.isEmpty { scheduleRetry() }
                paintSync()
                return
            } catch {
                flushing = false
                scheduleRetry()
                paintSync()
                return
            }
        }
    }

    private func quarantine(_ err: ApplyResult.ApplyError) {
        guard let id = err.id,
              let idx = queue.firstIndex(where: { $0.id == id }) else {
            banner = err.message
            return
        }
        queue[idx].tries = (queue[idx].tries ?? 0) + 1
        let maxTries = config?.maxOpTries ?? 5
        if queue[idx].tries! < maxTries {
            saveQueue()
            banner = "\(err.message ?? "error") (attempt \(queue[idx].tries!) of \(maxTries))"
            return
        }
        let removed = queue.remove(at: idx)
        saveQueue()
        let info = blockInfo(removed)
        dead.append(DeadEntry(
            at: Date().timeIntervalSince1970 * 1000,
            why: err.message ?? "failed",
            op: removed,
            key: info.key,
            startMs: info.startMs
        ))
        if dead.count > 50 { dead = Array(dead.suffix(50)) }
        saveDead()

        var cleared = false
        let openedRef: String? = {
            switch removed.type {
            case "openActual": return removed.ref
            case "splitActual": return removed.newRef
            case "undoSwitch": return removed.prevRef
            default: return nil
            }
        }()
        if let openedRef, open?.ref == openedRef {
            var back: OpenBlock?
            let keepRef = removed.type == "splitActual" ? removed.ref
                : removed.type == "undoSwitch" ? removed.newRef : nil
            if let keepRef, let e = blocks[keepRef], let key = e.key, let start = e.startMs {
                back = OpenBlock(ref: keepRef, key: key, text: "", startMs: start)
            }
            open = back
            cleared = true
        }
        if removed.type == "openSit", sit?.ref == removed.ref {
            sit = nil
            standStartMs = clock()
            cleared = true
        }
        if removed.type == "undoSwitch", let sitRef = removed.sitRef, sit?.ref == sitRef {
            sit = nil
            standStartMs = clock()
            cleared = true
        }
        if cleared {
            persist()
            syncLiveActivity()
        }
        banner = deadMsg() + " — the last: \(err.message ?? "failed")"
        syncFailed = true
        paintSync()
    }

    private func scheduleRetry() {
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 60)
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.flushAsync()
        }
    }

    // MARK: - Queue / helpers

    @discardableResult
    private func enqueue(_ op: Op) -> String {
        var op = op
        if op.id.isEmpty { op.id = Op.uid() }
        if op.ts == nil { op.ts = clock() }
        localGen += 1
        noteBlock(op)
        queue.append(op)
        saveQueue()
        paintSync()
        return op.id
    }

    private func dropOps(_ ids: [String]) -> Bool {
        if flushing { return false }
        let want = Set(ids.filter { !$0.isEmpty })
        guard !want.isEmpty else { return false }
        let hit = queue.filter { want.contains($0.id) }.count
        guard hit == want.count else { return false }
        queue = queue.filter { !want.contains($0.id) }
        saveQueue()
        paintSync()
        return true
    }

    private func mutatePendingOpen(ref: String, key: String) -> Bool {
        if flushing { return false }
        var hit = false
        for i in queue.indices {
            if queue[i].type == "openActual", queue[i].ref == ref {
                queue[i].key = key
                hit = true
            }
            if queue[i].type == "splitActual", queue[i].newRef == ref {
                queue[i].newKey = key
                hit = true
            }
        }
        if hit {
            queue.forEach(noteBlock)
            saveQueue()
        }
        return hit
    }

    private func pendingOpenSit(_ ref: String) -> String? {
        queue.first(where: { $0.type == "openSit" && $0.ref == ref })?.id
    }

    private func closeSit(at now: Double) -> ClosedSit? {
        guard let cur = sit else { return nil }
        let id = enqueue(Op(id: Op.uid(), type: "closeSit", ts: now, ref: cur.ref, endMs: now))
        sit = nil
        standStartMs = now
        return ClosedSit(ref: cur.ref, startMs: cur.startMs, closeId: id)
    }

    private func markFor(key: String, durMs: Double) -> (mark: String?, strip: Bool) {
        if let auto = catByKey[key]?.autoMark, auto != "?" { return (auto, false) }
        let minMs = Double(config?.minMarkMinutes ?? 15) * msMin
        if durMs >= minMs { return ("=", true) }
        return (nil, false)
    }

    private func railClosed(_ block: OpenBlock, endMs: Double, distractedMs: Double? = nil) {
        let dayStart = Format.dayStartMs(endMs)
        today = today.filter { $0.startMs >= dayStart }
        today.append(TodayBlock(
            ref: block.ref, key: block.key, startMs: block.startMs, endMs: endMs,
            text: block.text, distractedMs: distractedMs
        ))
    }

    private func railReopen(_ ref: String) {
        today = today.filter { $0.ref != ref }
    }

    private func closeBlockSheets() {
        split = nil
        sitEdit = nil
    }

    private func noteBlock(_ op: Op) {
        if let ref = op.ref {
            var e = blocks[ref] ?? BlockMeta()
            if let key = op.key { e.key = key }
            if (op.type == "openActual" || op.type == "openSit" || op.type == "setSitStart"),
               let start = op.startMs {
                e.startMs = start
            }
            if e.startMs == nil, let hint = op.hintMs { e.startMs = hint }
            blocks[ref] = e
        }
        if let newRef = op.newRef {
            var n = blocks[newRef] ?? BlockMeta()
            if let key = op.newKey { n.key = key }
            if let at = op.atMs { n.startMs = at }
            blocks[newRef] = n
        }
        if blocks.count > 200 {
            let keys = blocks.keys.sorted {
                (blocks[$0]?.startMs ?? 0) < (blocks[$1]?.startMs ?? 0)
            }
            keys.prefix(blocks.count - 200).forEach { blocks.removeValue(forKey: $0) }
        }
        saveBlocks()
    }

    private func blockInfo(_ op: Op) -> (key: String?, startMs: Double?) {
        if op.type == "undoSwitch" {
            let pe = op.prevRef.flatMap { blocks[$0] }
            return (
                op.prevKey ?? pe?.key,
                op.prevStartMs ?? pe?.startMs
            )
        }
        let e = op.ref.flatMap { blocks[$0] }
        var start: Double?
        if (op.type == "openActual" || op.type == "openSit"), let s = op.startMs { start = s }
        if start == nil { start = op.hintMs ?? e?.startMs }
        return (op.key ?? e?.key, start)
    }

    private func deadMsg() -> String {
        let n = dead.count
        return "\(n) write\(n == 1 ? " was" : "s were") set aside after repeated failures ›"
    }

    private func showMarkStrip(_ strip: MarkStrip) {
        markTimer?.invalidate()
        markStrip = strip
        let ms = config?.markTimeoutMs ?? 6000
        markTimer = Timer.scheduledTimer(withTimeInterval: Double(ms) / 1000, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.hideMarkStrip() }
        }
    }

    func hideMarkStrip() {
        markTimer?.invalidate()
        markTimer = nil
        markStrip = nil
    }

    private func armPending() {
        pendingTimer?.invalidate()
        let secs = Double(config?.undoSeconds ?? 5)
        pendingUntil = Date().addingTimeInterval(secs)
        undoLabel = pendingRibbonLabel()
        paintPending()
        pendingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.paintPending() }
        }
    }

    private func pendingRibbonLabel() -> String {
        guard let key = pendingKey else { return "" }
        let name = labelFor(key).uppercased()
        if pendingStop { return "STOP \(name)" }
        if open != nil { return "SWITCH TO \(name)" }
        return "START \(name)"
    }

    private func paintPending() {
        guard pendingKey != nil, let until = pendingUntil else {
            clearPending()
            return
        }
        let left = Int(ceil(until.timeIntervalSinceNow))
        if left <= 0 {
            commitPending()
            return
        }
        undoLabel = pendingRibbonLabel()
        undoSecondsLeft = max(1, left)
    }

    private func clearPending() {
        pendingTimer?.invalidate()
        pendingTimer = nil
        pendingUntil = nil
        pendingKey = nil
        pendingStop = false
        if undo == nil {
            undoLabel = nil
            undoSecondsLeft = 0
        }
    }

    private func armUndo(_ offer: UndoOffer) {
        clearUndo()
        undo = offer
        undoLabel = offer.label
        paintUndo()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.paintUndo() }
        }
    }

    private func clearUndo() {
        undoTimer?.invalidate()
        undoTimer = nil
        undo = nil
        undoLabel = nil
        undoSecondsLeft = 0
    }

    private func paintUndo() {
        guard let u = undo else {
            undoLabel = nil
            undoSecondsLeft = 0
            return
        }
        let left = Int(ceil(u.until.timeIntervalSinceNow))
        if left <= 0 {
            clearUndo()
            return
        }
        undoLabel = u.label
        undoSecondsLeft = max(1, left)
    }

    /// Always on: one is sitting or standing. Ends only on sign-out.
    private func syncLiveActivity() {
        guard NSClassFromString("XCTestCase") == nil else { return }
        if sit == nil && standStartMs == nil {
            standStartMs = clock()
        }
        let state = RunningBlockAttributes.ContentState(
            key: open?.key,
            face: open.map { labelFor($0.key) },
            hex: open.flatMap { catByKey[$0.key]?.hex },
            startMs: open?.startMs,
            sitting: sit != nil,
            sitStartMs: sit?.startMs,
            standStartMs: standStartMs
        )
        Task { await RunningBlockSync.apply(state) }
    }

    private func paintSync() {
        if lastInsertFailed {
            syncLabel = "sync failed"
            syncFailed = true
            return
        }
        if !GoogleAuth.hasSession || !sessionReady {
            syncLabel = "waiting"
            syncFailed = false
            return
        }
        if banner != nil, queue.isEmpty, dead.isEmpty {
            syncLabel = "waiting"
            syncFailed = true
            return
        }
        if !dead.isEmpty {
            syncLabel = queue.isEmpty
                ? "\(dead.count) set aside"
                : "\(dead.count) set aside · retrying"
            syncFailed = true
        } else if flushing && !queue.isEmpty {
            syncLabel = "syncing · \(queue.count)"
            syncFailed = false
        } else if !queue.isEmpty {
            syncLabel = "waiting"
            syncFailed = true
        } else {
            syncLabel = "synced"
            syncFailed = false
        }
    }

    // MARK: - Persistence

    private func loadPersisted() {
        if let data = UserDefaults.standard.data(forKey: queueKey) {
            if let q = try? JSONDecoder().decode([Op].self, from: data) {
                queue = q
            } else {
                persistBroken = true
                banner = "could not read the saved queue. Nothing was overwritten."
            }
        }
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let st = try? JSONDecoder().decode(Persisted.self, from: data) {
            open = st.open
            sit = st.sit
            today = st.today ?? []
            planToday = st.planToday ?? []
            standStartMs = st.standStartMs
            lastUsed = st.lastUsed ?? [:]
            distracted = st.distracted ?? false
            distractedAccruedMs = st.distractedAccruedMs ?? 0
            distractStartMs = st.distractStartMs
        }
        if let data = UserDefaults.standard.data(forKey: deadKey),
           let d = try? JSONDecoder().decode([DeadEntry].self, from: data) {
            dead = d
        }
        if let data = UserDefaults.standard.data(forKey: blocksKey),
           let b = try? JSONDecoder().decode([String: BlockMeta].self, from: data) {
            blocks = b
        }
        queue.forEach(noteBlock)
        if !dead.isEmpty { banner = deadMsg() }
        if let data = UserDefaults.standard.data(forKey: configKey) {
            if let cfg = try? JSONDecoder().decode(ClientConfig.self, from: data) {
                applyConfig(cfg, write: false)
            } else {
                applyConfig(.seed, write: false)
            }
        } else {
            applyConfig(.seed)
        }
        paintSync()
        syncLiveActivity()
    }

    private func persist() {
        let st = Persisted(
            open: open, sit: sit, today: today, standStartMs: standStartMs, lastUsed: lastUsed,
            planToday: planToday, distracted: distracted,
            distractedAccruedMs: distractedAccruedMs, distractStartMs: distractStartMs
        )
        if let data = try? JSONEncoder().encode(st) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    private func saveQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
        paintSync()
    }

    private func saveDead() {
        if let data = try? JSONEncoder().encode(dead) {
            UserDefaults.standard.set(data, forKey: deadKey)
        }
    }

    private func saveBlocks() {
        if let data = try? JSONEncoder().encode(blocks) {
            UserDefaults.standard.set(data, forKey: blocksKey)
        }
    }

    static func normalize(_ cfg: ClientConfig) -> ClientConfig {
        migrateBody(migrateSeedColors(cfg))
    }

    /// Old installs seeded Poop as lavender 1 (Deep work's hue). Banana is 5.
    static func migrateSeedColors(_ cfg: ClientConfig) -> ClientConfig {
        var cfg = cfg
        for gi in cfg.groups.indices {
            for ci in cfg.groups[gi].children.indices {
                let c = cfg.groups[gi].children[ci]
                if c.label.lowercased() == "poop"
                    && (c.color == "1" || c.hex.lowercased() == "#7986cb") {
                    cfg.groups[gi].children[ci].color = "5"
                    cfg.groups[gi].children[ci].hex = "#f6bf26"
                }
            }
        }
        return cfg
    }

    /// A stored Body leaf becomes the three Body children. Body itself is retired.
    static func migrateBody(_ cfg: ClientConfig) -> ClientConfig {
        var cfg = cfg
        guard let i = cfg.groups.firstIndex(where: { $0.label.lowercased() == "body" }) else {
            return cfg
        }
        let kids = cfg.groups[i].children.map { $0.label.lowercased() }
        if kids.contains("zone 2") { return cfg }
        guard kids == ["body"] || kids.isEmpty else { return cfg }
        let color = cfg.groups[i].color.isEmpty ? "10" : cfg.groups[i].color
        let hex = cfg.groups[i].hex.isEmpty ? (TT.colorHex[color] ?? "#0b8043") : cfg.groups[i].hex
        cfg.groups[i].autoMark = "+"
        cfg.groups[i].color = color
        cfg.groups[i].hex = hex
        cfg.groups[i].children = ["Zone 2", "Lifting", "Walking"].map {
            Category(label: $0, color: color, hex: hex, autoMark: "+")
        }
        if !cfg.retired.contains(where: { $0.lowercased() == "body" }) {
            cfg.retired.append("Body")
        }
        return cfg
    }

    private struct Persisted: Codable {
        var open: OpenBlock?
        var sit: SitBlock?
        var today: [TodayBlock]?
        var standStartMs: Double?
        var lastUsed: [String: String]?
        var planToday: [TodayBlock]?
        var distracted: Bool?
        var distractedAccruedMs: Double?
        var distractStartMs: Double?
    }
}
