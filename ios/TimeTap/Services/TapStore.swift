import Foundation
import SwiftUI
import Combine

@MainActor
final class TapStore: ObservableObject {
    @Published var config: ClientConfig?
    @Published var open: OpenBlock?
    @Published var sit: SitBlock?
    @Published var today: [TodayBlock] = []
    @Published var queue: [Op] = []
    @Published var dead: [DeadEntry] = []
    @Published var syncLabel = "GOOGLE CALENDAR · SYNCED"
    @Published var syncFailed = false
    @Published var banner: String?
    @Published var showSettings = false
    @Published var showSignIn = false
    @Published var showPicker = false
    @Published var showDead = false
    @Published var addingCategory = false
    var lastInsertFailed = false

    @Published var undoLabel: String?
    @Published var undoSecondsLeft: Int = 0
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
    private var catByKey: [String: Category] = [:]
    private var blocks: [String: BlockMeta] = [:]

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
        if !GoogleAuth.hasSession {
            showSignIn = true
        } else if !Credentials.hasCalendarIds {
            showPicker = true
        }
    }

    func signOut() {
        GoogleAuth.signOut()
        showSignIn = true
        showSettings = false
    }

    func boot() { Task { await bootAsync() } }

    func refreshOnReturn() {
        guard Credentials.isConfigured, queue.isEmpty, config != nil else { return }
        let overdue = Date().timeIntervalSince(lastStateAt) > 10 * 60
        let runaway = open.map {
            Date().timeIntervalSince1970 * 1000 - $0.startMs
                > Double(config?.staleOpenHours ?? 5) * 3_600_000
        } ?? false
        if overdue || runaway { Task { await loadServerState() } }
    }

    // MARK: - Capture actions

    func tapCategory(_ key: String) {
        if Credentials.actualId.isEmpty {
            banner = "Pick PLAN, ACTUAL and SITTING calendars first."
            if GoogleAuth.hasSession { showPicker = true }
            return
        }
        guard GoogleAuth.hasSession else {
            showSignIn = true
            return
        }
        let now = clock()
        if now - lastTapMs < 300 { return }
        lastTapMs = now
        if let open, open.key == key {
            if lastInsertFailed {
                retryLastInsert()
                return
            }
            if undo != nil { return }
            openSplit()
            return
        }

        closeBlockSheets()

        var prev: OpenBlock?
        var closeId: String?
        var pending: MarkStrip?
        if let cur = open {
            prev = cur
            let dur = now - cur.startMs
            let m = markFor(key: cur.key, durMs: dur)
            closeId = enqueue(Op(
                id: Op.uid(), type: "closeActual", ts: now,
                ref: cur.ref, key: cur.key, text: cur.text, mark: m.mark, endMs: now
            ))
            if m.strip {
                pending = MarkStrip(ref: cur.ref, key: cur.key, durMs: dur, hintMs: cur.startMs)
            }
            railClosed(cur, endMs: now)
        }

        let ref = Op.uid()
        open = OpenBlock(ref: ref, key: key, startMs: now)
        let openId = enqueue(Op(
            id: Op.uid(), type: "openActual", ts: now,
            ref: ref, key: key, startMs: now
        ))

        if let pending { showMarkStrip(pending) } else { hideMarkStrip() }
        armUndo(UndoOffer(
            prev: prev, newRef: ref, atMs: now,
            closeId: closeId, openId: openId, sit: nil,
            label: "SWITCHED TO \(labelFor(key).uppercased())",
            until: Date().addingTimeInterval(Double(config?.undoSeconds ?? 5))
        ))
        unreadableOpen = false
        scrollToKey = key
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
        let now = clock()
        closeBlockSheets()
        var prev: OpenBlock?
        var closeId: String?
        var pending: MarkStrip?

        if let cur = open {
            prev = cur
            let dur = now - cur.startMs
            let m = markFor(key: cur.key, durMs: dur)
            closeId = enqueue(Op(
                id: Op.uid(), type: "closeActual", ts: now,
                ref: cur.ref, key: cur.key, text: cur.text, mark: m.mark, endMs: now
            ))
            railClosed(cur, endMs: now)
            pending = m.strip
                ? MarkStrip(ref: cur.ref, key: cur.key, durMs: dur, hintMs: cur.startMs)
                : nil
            open = nil
            if let pending { showMarkStrip(pending) } else { hideMarkStrip() }
        }

        let sitClosed = closeSit(at: now)
        if prev != nil || sitClosed != nil {
            armUndo(UndoOffer(
                prev: prev, newRef: nil, atMs: now,
                closeId: closeId, openId: nil, sit: sitClosed,
                label: "STOPPED — NOW UNLOGGED",
                until: Date().addingTimeInterval(Double(config?.undoSeconds ?? 5))
            ))
        }
        unreadableOpen = false
        persist()
        flush()
    }

    func toggleSit() {
        let now = clock()
        if sit != nil {
            _ = closeSit(at: now)
        } else {
            let ref = Op.uid()
            sit = SitBlock(ref: ref, startMs: now)
            _ = enqueue(Op(id: Op.uid(), type: "openSit", ts: now, ref: ref, startMs: now))
        }
        persist()
        flush()
    }

    func takeUndo() {
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
        noteTask?.cancel()
        let ref = cur.ref
        let hint = cur.startMs
        noteTask = Task {
            try? await Task.sleep(nanoseconds: noteDelayNs)
            guard !Task.isCancelled else { return }
            queue = queue.filter { !($0.type == "setText" && $0.ref == ref) }
            _ = enqueue(Op(
                id: Op.uid(), type: "setText",
                ts: clock(),
                ref: ref, text: text, hintMs: hint
            ))
            flush()
        }
    }

    // MARK: - Split

    func openSplit() {
        guard let cur = open else { return }
        clearUndo()
        let now = clock()
        let span = max(1, Int(((now - cur.startMs) / msMin).rounded()))
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
        guard let s = split, let cur = open, cur.ref == s.ref else {
            split = nil
            return
        }
        if s.whole {
            recatWhole(key: key)
            return
        }
        let now = clock()
        let m = markFor(key: cur.key, durMs: s.atMs - cur.startMs)
        let newRef = Op.uid()
        _ = enqueue(Op(
            id: Op.uid(), type: "splitActual", ts: now,
            ref: cur.ref, text: cur.text, mark: m.mark,
            atMs: s.atMs, nowMs: now, newRef: newRef, newKey: key
        ))
        railClosed(cur, endMs: s.atMs)
        open = OpenBlock(ref: newRef, key: key, startMs: s.atMs)
        hideMarkStrip()
        split = nil
        persist()
        flush()
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
    }

    func deleteSit() {
        guard let cur = sit else { return }
        _ = enqueue(Op(
            id: Op.uid(), type: "deleteSit",
            ts: clock(),
            ref: cur.ref, hintMs: cur.startMs
        ))
        sit = nil
        sitEdit = nil
        persist()
        flush()
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
        let dayStart = Format.dayStartMs(now)
        var blocks = today.filter { $0.endMs > dayStart }
        if let open {
            blocks.append(TodayBlock(
                ref: open.ref, key: open.key, startMs: open.startMs, endMs: now
            ))
        }
        blocks.sort { $0.startMs < $1.startMs }
        guard let firstBlock = blocks.first else { return ("", []) }

        let first = max(firstBlock.startMs, dayStart)
        let span = max(now - first, 60_000)
        var raw: [(name: String, ms: Double, hex: String?, gap: Bool, open: Bool, floor: CGFloat)] = []
        var prevEnd: Double?

        for b in blocks {
            if let pe = prevEnd, b.startMs - pe > gapMs {
                raw.append(("UNLOGGED", b.startMs - pe, nil, true, false, 20))
            }
            let cat = catByKey[b.key]
            let ms = b.endMs - max(b.startMs, dayStart)
            let isOpen = open.map { o in
                (b.ref != nil && b.ref == o.ref) || (b.ref == nil && b.startMs == o.startMs && b.endMs == now)
            } ?? false
            raw.append((
                (cat?.face ?? b.key).uppercased(),
                ms,
                cat?.hex,
                false,
                isOpen,
                26
            ))
            prevEnd = max(prevEnd ?? b.endMs, b.endMs)
        }
        if open == nil, let pe = prevEnd, now - pe > 5000 {
            raw.append(("UNLOGGED", now - pe, nil, true, false, 20))
        }

        let px = budget / span
        let share = budget / CGFloat(max(1, raw.count))
        var heights = raw.map { max(CGFloat($0.ms) * px, min($0.floor, share)) }
        let total = heights.reduce(0, +)
        if total > budget {
            let k = budget / total
            heights = heights.map { $0 * k }
        }

        let items = zip(raw.indices, zip(raw, heights)).map { idx, pair in
            let (r, h) = pair
            return RailItem(
                id: "\(idx)",
                name: r.name, ms: r.ms, hex: r.hex,
                isGap: r.gap, isOpen: r.open, height: max(h, 1)
            )
        }
        return ("TODAY · \(Format.clock(first))", items)
    }

    func labelFor(_ key: String) -> String { catByKey[key]?.face ?? key }
    func colorFor(_ key: String) -> Color { Theme.hex(catByKey[key]?.hex ?? "#616161") }
    var categories: [Category] { config?.categories ?? [] }
    var deadCount: Int { dead.count }
    var canAddCategory: Bool {
        categories.count < (config?.maxCategories ?? 10)
    }

    var nowKick: String {
        guard let open else { return "NOTHING RUNNING — TIME IS UNLOGGED" }
        return "NOW · SINCE \(Format.clock(open.startMs).uppercased())"
    }

    func addCategory(label: String, onSuccess: (() -> Void)? = nil) {
        let name = String(label)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = String(name.prefix(24))
        guard !clipped.isEmpty else {
            banner = "A category needs a name."
            return
        }
        var cats = config?.categories ?? ClientConfig.seed.categories
        let max = config?.maxCategories ?? TT.maxCategories
        if cats.count >= max {
            banner = "That is \(max) categories already."
            return
        }
        if let hit = cats.first(where: { $0.label.lowercased() == clipped.lowercased() }) {
            banner = "There is already a category called \(hit.label)."
            return
        }
        let key = Grammar.keyFor(clipped, taken: cats)
        let color = Grammar.nextColor(cats)
        cats.append(Category(
            key: key, label: clipped, color: color,
            hex: TT.colorHex[color] ?? "#616161", autoMark: nil
        ))
        var cfg = config ?? .seed
        cfg.categories = cats
        applyConfig(cfg)
        addingCategory = false
        banner = nil
        onSuccess?()
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

    private func bootAsync() async {
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

    private func applyConfig(_ cfg: ClientConfig) {
        config = cfg
        catByKey = Dictionary(cfg.categories.map { ($0.key, $0) }, uniquingKeysWith: { _, n in n })
        Grammar.extraColors = [:]
        for c in cfg.categories where TT.colorIdByKey[c.key] == nil && !c.color.isEmpty {
            Grammar.extraColors[c.key] = c.color
        }
        if let data = try? JSONEncoder().encode(cfg) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
        refreshUnreadable()
    }

    private func loadServerState(corrective: Bool = false) async {
        let gen = localGen
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
        } catch {
            banner = error.localizedDescription
        }
    }

    private func adoptServerState(_ st: ServerState, gen: Int) -> Bool {
        if gen != localGen || !queue.isEmpty { return false }
        let wasRef = open?.ref
        let wasSit = sit?.ref
        open = st.open
        sit = st.sit
        today = st.today ?? []
        if wasRef != open?.ref || wasSit != sit?.ref {
            closeBlockSheets()
        }
        persist()
        refreshUnreadable()
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
        flushTask?.cancel()
        flushTask = Task { [weak self] in await self?.flushAsync() }
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
                if http.status == 429 || http.status >= 500 {
                    transportFails += 1
                    banner = "Google Calendar is unreachable. The running block is still here."
                    if transportFails < 5 { scheduleRetry() }
                    paintSync()
                    return
                }
                if http.status >= 400, let id = queue.first?.id {
                    quarantine(.init(id: id, message: "HTTP \(http.status)"))
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
        if removed.type == "openActual", open?.ref == removed.ref {
            open = nil
            cleared = true
        }
        if removed.type == "openSit", sit?.ref == removed.ref {
            sit = nil
            cleared = true
        }
        if cleared { persist() }
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
        return ClosedSit(ref: cur.ref, startMs: cur.startMs, closeId: id)
    }

    private func markFor(key: String, durMs: Double) -> (mark: String?, strip: Bool) {
        if let auto = catByKey[key]?.autoMark, auto != "?" { return (auto, false) }
        let minMs = Double(config?.minMarkMinutes ?? 15) * msMin
        if durMs >= minMs { return ("=", true) }
        return (nil, false)
    }

    private func railClosed(_ block: OpenBlock, endMs: Double) {
        let dayStart = Format.dayStartMs(endMs)
        today = today.filter { $0.startMs >= dayStart }
        today.append(TodayBlock(ref: block.ref, key: block.key, startMs: block.startMs, endMs: endMs))
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

    private func paintSync() {
        if lastInsertFailed {
            syncLabel = "SYNC FAILED"
            syncFailed = true
            return
        }
        if !dead.isEmpty {
            syncLabel = "\(dead.count) SET ASIDE · RETRYING"
            syncFailed = true
        } else if flushing && !queue.isEmpty {
            syncLabel = "SYNCING · \(queue.count)"
            syncFailed = false
        } else if !queue.isEmpty {
            syncLabel = "GOOGLE CALENDAR · WAITING"
            syncFailed = true
        } else {
            syncLabel = "GOOGLE CALENDAR · SYNCED"
            syncFailed = false
        }
    }

    // MARK: - Persistence

    private func loadPersisted() {
        if let data = UserDefaults.standard.data(forKey: queueKey),
           let q = try? JSONDecoder().decode([Op].self, from: data) {
            queue = q
        }
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let st = try? JSONDecoder().decode(Persisted.self, from: data) {
            open = st.open
            sit = st.sit
        }
        if let data = UserDefaults.standard.data(forKey: deadKey),
           let d = try? JSONDecoder().decode([DeadEntry].self, from: data) {
            dead = d
        }
        if let data = UserDefaults.standard.data(forKey: blocksKey),
           let b = try? JSONDecoder().decode([String: BlockMeta].self, from: data) {
            blocks = b
        }
        if let data = UserDefaults.standard.data(forKey: configKey),
           let cfg = try? JSONDecoder().decode(ClientConfig.self, from: data) {
            applyConfig(cfg)
        } else {
            applyConfig(.seed)
        }
        paintSync()
    }

    private func persist() {
        let st = Persisted(open: open, sit: sit)
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

    private struct Persisted: Codable {
        var open: OpenBlock?
        var sit: SitBlock?
    }
}
