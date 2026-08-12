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
    @Published var syncLabel = "GOOGLE CALENDAR · SYNCED"
    @Published var syncFailed = false
    @Published var banner: String?
    @Published var showSettings = false

    @Published var undoLabel: String?
    @Published var undoSecondsLeft: Int = 0

    @Published var markStrip: MarkStrip?

    struct MarkStrip: Equatable {
        var ref: String
        var key: String
        var durMs: Double
        var hintMs: Double
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

    private var undo: UndoOffer?
    private var undoTimer: Timer?
    private var markTimer: Timer?
    private var noteTask: Task<Void, Never>?
    private var flushTask: Task<Void, Never>?
    private var flushing = false
    private var localGen = 0
    private var lastStateAt = Date.distantPast
    private var retryDelay: TimeInterval = 4
    private var catByKey: [String: Category] = [:]

    private let queueKey = "tt.queue.v1"
    private let stateKey = "tt.state.v1"
    private let msMin: Double = 60_000

    init() {
        loadPersisted()
        if !Credentials.isConfigured {
            showSettings = true
        }
    }

    func boot() {
        Task { await bootAsync() }
    }

    func refreshOnReturn() {
        guard Credentials.isConfigured, queue.isEmpty else { return }
        let overdue = Date().timeIntervalSince(lastStateAt) > 10 * 60
        let runaway = open.map {
            Date().timeIntervalSince1970 * 1000 - $0.startMs > Double((config?.staleOpenHours ?? 5)) * 3_600_000
        } ?? false
        if overdue || runaway {
            Task { await loadServerState() }
        }
    }

    // MARK: - Actions

    func tapCategory(_ key: String) {
        let now = Date().timeIntervalSince1970 * 1000
        if let open, open.key == key {
            if undo != nil { return }
            // Split sheet deferred to a later pass — ignore re-tap for v1.
            return
        }

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
        persist()
        flush()
    }

    func endDay() {
        let now = Date().timeIntervalSince1970 * 1000
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
        persist()
        flush()
    }

    func toggleSit() {
        let now = Date().timeIntervalSince1970 * 1000
        if sit != nil {
            _ = closeSit(at: now)
        } else {
            let ref = Op.uid()
            sit = SitBlock(ref: ref, startMs: now)
            _ = enqueue(Op(
                id: Op.uid(), type: "openSit", ts: now,
                ref: ref, startMs: now
            ))
        }
        persist()
        flush()
    }

    func takeUndo() {
        guard let u = undo else { return }
        clearUndo()
        let now = Date().timeIntervalSince1970 * 1000

        var ids: [String?] = [u.closeId, u.openId]
        if let s = u.sit { ids.append(s.closeId) }
        if !dropOps(ids.compactMap { $0 }) {
            _ = enqueue(Op(
                id: Op.uid(), type: "undoSwitch", ts: now,
                atMs: u.atMs, nowMs: now, newRef: u.newRef,
                prevRef: u.prev?.ref, prevKey: u.prev?.key,
                prevText: u.prev?.text, prevStartMs: u.prev?.startMs,
                sitRef: u.sit?.ref, sitStartMs: u.sit?.startMs
            ))
        }

        if let prev = u.prev {
            queue = queue.filter { !($0.type == "setMark" && $0.ref == prev.ref) }
            saveQueue()
            if let idx = today.firstIndex(where: { $0.startMs == prev.startMs && $0.key == prev.key }) {
                today.remove(at: idx)
            }
        }
        open = u.prev
        if let s = u.sit {
            sit = SitBlock(ref: s.ref, startMs: s.startMs)
        }
        hideMarkStrip()
        persist()
        flush()
    }

    func applyMark(_ mark: String) {
        guard let strip = markStrip else { return }
        hideMarkStrip()
        if mark != "=" {
            _ = enqueue(Op(
                id: Op.uid(), type: "setMark", ts: Date().timeIntervalSince1970 * 1000,
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
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            queue = queue.filter { !($0.type == "setText" && $0.ref == ref) }
            _ = enqueue(Op(
                id: Op.uid(), type: "setText",
                ts: Date().timeIntervalSince1970 * 1000,
                ref: ref, text: text, hintMs: hint
            ))
            flush()
        }
    }

    func labelFor(_ key: String) -> String {
        catByKey[key]?.face ?? key
    }

    func colorFor(_ key: String) -> Color {
        Theme.hex(catByKey[key]?.hex ?? "#616161")
    }

    // MARK: - Boot / network

    private func bootAsync() async {
        guard Credentials.isConfigured else {
            showSettings = true
            banner = "Add the API URL and token to start"
            return
        }
        do {
            let cfg = try await TimetapAPI.shared.config()
            applyConfig(cfg)
            if !queue.isEmpty {
                paintSync()
                await flushAsync()
            }
            await loadServerState()
        } catch {
            banner = error.localizedDescription
            syncFailed = true
            paintSync()
        }
    }

    func saveSettingsAndReconnect(url: String, token: String) {
        Credentials.apiURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        Credentials.apiToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        showSettings = false
        banner = nil
        boot()
    }

    private func applyConfig(_ cfg: ClientConfig) {
        config = cfg
        catByKey = Dictionary(uniqueKeysWithValues: cfg.categories.map { ($0.key, $0) })
    }

    private func loadServerState() async {
        let gen = localGen
        do {
            let st = try await TimetapAPI.shared.getState()
            guard gen == localGen, queue.isEmpty else { return }
            open = st.open.map {
                OpenBlock(ref: $0.ref, key: $0.key, text: $0.text, startMs: $0.startMs)
            }
            sit = st.sit
            today = st.today ?? []
            lastStateAt = Date()
            banner = nil
            persist()
        } catch {
            banner = error.localizedDescription
        }
    }

    func flush() {
        flushTask?.cancel()
        flushTask = Task { await flushAsync() }
    }

    private func flushAsync() async {
        guard !flushing, Credentials.isConfigured else { return }
        let batch = Array(queue.prefix(40))
        guard !batch.isEmpty else {
            syncFailed = false
            paintSync()
            return
        }
        flushing = true
        paintSync()
        defer { flushing = false }

        do {
            let res = try await TimetapAPI.shared.applyOps(batch)
            let done = Set(res.applied ?? [])
            queue = queue.filter { !done.contains($0.id) }
            saveQueue()

            if batch.contains(where: { $0.type == "undoSwitch" && done.contains($0.id) }) {
                await loadServerState()
            }

            if let err = res.errors?.first {
                await quarantine(err)
                syncFailed = true
                paintSync()
                scheduleRetry()
            } else {
                banner = nil
                retryDelay = 4
                if queue.isEmpty {
                    syncFailed = false
                    paintSync()
                    await loadServerState()
                } else {
                    await flushAsync()
                }
            }
        } catch {
            syncFailed = true
            banner = error.localizedDescription
            paintSync()
            scheduleRetry()
        }
    }

    private func quarantine(_ err: ApplyResult.ApplyError) async {
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
        // Set aside: drop from queue. Full dead-letter drawer is web-parity later.
        let removed = queue.remove(at: idx)
        saveQueue()
        if removed.type == "openActual", open?.ref == removed.ref {
            open = nil
            persist()
        }
        banner = "1 SET ASIDE — \(err.message ?? "write failed")"
        syncFailed = true
        paintSync()
    }

    private func scheduleRetry() {
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 60)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await flushAsync()
        }
    }

    // MARK: - Queue helpers

    @discardableResult
    private func enqueue(_ op: Op) -> String {
        var op = op
        if op.id.isEmpty { op.id = Op.uid() }
        if op.ts == nil { op.ts = Date().timeIntervalSince1970 * 1000 }
        localGen += 1
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

    private func closeSit(at now: Double) -> ClosedSit? {
        guard let cur = sit else { return nil }
        let id = enqueue(Op(
            id: Op.uid(), type: "closeSit", ts: now,
            ref: cur.ref, endMs: now
        ))
        sit = nil
        return ClosedSit(ref: cur.ref, startMs: cur.startMs, closeId: id)
    }

    private func markFor(key: String, durMs: Double) -> (mark: String?, strip: Bool) {
        if let auto = catByKey[key]?.autoMark, auto != "?" {
            return (auto, false)
        }
        let minMs = Double(config?.minMarkMinutes ?? 15) * msMin
        if durMs >= minMs { return ("=", true) }
        return (nil, false)
    }

    private func railClosed(_ block: OpenBlock, endMs: Double) {
        today.append(TodayBlock(key: block.key, startMs: block.startMs, endMs: endMs))
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
        if syncFailed && queue.isEmpty {
            syncLabel = "SET ASIDE · RETRYING"
        } else if !queue.isEmpty {
            syncLabel = "SYNCING · \(queue.count)"
        } else {
            syncLabel = "GOOGLE CALENDAR · SYNCED"
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

    private struct Persisted: Codable {
        var open: OpenBlock?
        var sit: SitBlock?
    }
}
