import Foundation

enum ApplyOps {
    static var nowMs: Double = Date().timeIntervalSince1970 * 1000
    static var actual: FakeCalendar?
    static var sitting: FakeCalendar?
    static let msMin: Double = 60_000
    static let msHour: Double = 3_600_000

    static func resetForTests() {
        nowMs = Date().timeIntervalSince1970 * 1000
        actual = nil
        sitting = nil
    }

    static func apply(_ ops: [Op]) -> ApplyResult {
        var out = ApplyResult(applied: [], errors: [], dropped: [])
        for op in ops {
            if !valid(op) {
                out.dropped = (out.dropped ?? []) + [.init(id: op.id.isEmpty ? nil : op.id)]
                if !op.id.isEmpty { out.applied = (out.applied ?? []) + [op.id] }
                continue
            }
            do {
                try applyOp(op)
                if !op.id.isEmpty { out.applied = (out.applied ?? []) + [op.id] }
            } catch {
                out.errors = (out.errors ?? []) + [.init(id: op.id, message: error.localizedDescription)]
                break
            }
        }
        return out
    }

    static func valid(_ op: Op) -> Bool {
        if op.type.isEmpty || op.id.isEmpty { return false }
        let ms = [op.startMs, op.endMs, op.atMs, op.nowMs, op.hintMs]
        for v in ms {
            if let v, !v.isFinite { return false }
        }
        let refs = [op.ref, op.newRef, op.killSitRef]
        for r in refs {
            if let r {
                if r.range(of: "^[A-Za-z0-9]{4,64}$", options: .regularExpression) == nil {
                    return false
                }
            }
        }
        if let mark = op.mark {
            if !Grammar.isMark(mark) || mark == "?" { return false }
        }
        return true
    }

    private static func applyOp(_ op: Op) throws {
        switch op.type {
        case "openActual": opOpenActual(op)
        case "closeActual": opCloseActual(op)
        case "recategorize": opRecategorize(op)
        case "setMark": opSetMark(op)
        case "setText": opSetText(op)
        case "splitActual": opSplitActual(op)
        case "openSit": opOpenSit(op)
        case "closeSit": opCloseSit(op)
        case "setSitStart": opSetSitStart(op)
        case "deleteSit": opDeleteSit(op)
        case "undoSwitch": return
        default: return
        }
    }

    static func endEventAt(_ ev: CalEvent, _ endMs: Double) {
        var e = endMs
        if !(e > ev.startMs) { e = ev.startMs + msMin }
        ev.endMs = e
    }

    static func isOpen(_ ev: CalEvent) -> Bool {
        ev.description.contains(TT.openToken)
    }

    static func writeDesc(_ ev: CalEvent, ref: String, isOpen: Bool) {
        ev.description = Grammar.writeDesc(ev.description, ref: ref, isOpen: isOpen)
    }

    static func refOf(_ ev: CalEvent) -> String {
        let pat = NSRegularExpression.escapedPattern(for: TT.refPrefix) + "([A-Za-z0-9]+)"
        if let m = Grammar.match(pat, ev.description) { return m[1] }
        let ref = Op.uid()
        writeDesc(ev, ref: ref, isOpen: isOpen(ev))
        return ref
    }

    static func findByRef(_ cal: FakeCalendar, _ ref: String?, hintMs: Double?) -> CalEvent? {
        guard let ref, !ref.isEmpty else { return nil }
        let h = hintMs ?? nowMs
        let lo = min(h, nowMs) - 36 * msHour
        let hi = max(h, nowMs) + 36 * msHour
        let needle = TT.refPrefix + ref
        return cal.events(from: lo, to: hi).reversed().first { $0.description.contains(needle) }
    }

    static func findOpen(_ cal: FakeCalendar) -> CalEvent? {
        let evs = cal.events(from: nowMs - 72 * msHour, to: nowMs + 24 * msHour)
        var open = evs.filter { !$0.isAllDay && isOpen($0) }
        guard !open.isEmpty else { return nil }
        open.sort { $0.startMs < $1.startMs }
        let newest = open[open.count - 1]
        for j in 0..<(open.count - 1) {
            endEventAt(open[j], newest.startMs)
            writeDesc(open[j], ref: refOf(open[j]), isOpen: false)
        }
        return newest
    }

    private static func applyCatColor(_ ev: CalEvent, _ key: String?) {
        guard let key else { return }
        let id = Grammar.colorId(for: key)
        if !id.isEmpty { ev.colorId = id }
    }

    private static func opOpenActual(_ op: Op) {
        guard let cal = actual else { return }
        if findByRef(cal, op.ref, hintMs: op.startMs) != nil { return }
        if let prev = findOpen(cal), refOf(prev) != op.ref {
            endEventAt(prev, op.startMs ?? nowMs)
            writeDesc(prev, ref: refOf(prev), isOpen: false)
        }
        let start = op.startMs ?? nowMs
        let ev = cal.createEvent(
            calendarId: Credentials.actualId,
            title: Grammar.buildTitle(op.key ?? "", "", nil),
            startMs: start, endMs: start + msMin
        )
        writeDesc(ev, ref: op.ref ?? "", isOpen: true)
        applyCatColor(ev, op.key)
    }

    private static func opCloseActual(_ op: Op) {
        guard let cal = actual else { return }
        guard let ev = findByRef(cal, op.ref, hintMs: op.endMs) else { return }
        let p = Grammar.parseTitle(ev.title)
            ?? ParsedTitle(key: op.key ?? TT.unfiledKey, text: ev.title, mark: nil)
        let text = op.text ?? p.text
        let closed = !isOpen(ev)
        // Vacuity: remove `!closed ||` and the stretch criterion goes red.
        if !closed || p.mark == "?" { endEventAt(ev, op.endMs ?? nowMs) }
        ev.title = Grammar.buildTitle(p.key, text, op.mark)
        writeDesc(ev, ref: op.ref ?? "", isOpen: false)
    }

    private static func opRecategorize(_ op: Op) {
        guard let cal = actual else { return }
        guard let ev = findByRef(cal, op.ref, hintMs: op.hintMs) else { return }
        let p = Grammar.parseTitle(ev.title) ?? ParsedTitle(key: op.key ?? "", text: "", mark: nil)
        ev.title = Grammar.buildTitle(op.key ?? "", p.text, p.mark)
        applyCatColor(ev, op.key)
    }

    private static func opSetMark(_ op: Op) {
        guard let cal = actual else { return }
        guard let ev = findByRef(cal, op.ref, hintMs: op.hintMs) else { return }
        guard let p = Grammar.parseTitle(ev.title) else { return }
        ev.title = Grammar.buildTitle(p.key, p.text, op.mark)
    }

    private static func opSetText(_ op: Op) {
        guard let cal = actual else { return }
        guard let ev = findByRef(cal, op.ref, hintMs: op.hintMs) else { return }
        guard let p = Grammar.parseTitle(ev.title) else { return }
        ev.title = Grammar.buildTitle(p.key, op.text ?? "", p.mark)
    }

    private static func opSplitActual(_ op: Op) {
        guard let cal = actual else { return }
        if let ev = findByRef(cal, op.ref, hintMs: op.atMs) {
            let p = Grammar.parseTitle(ev.title)
                ?? ParsedTitle(key: TT.unfiledKey, text: ev.title, mark: nil)
            let text = op.text ?? p.text
            ev.title = Grammar.buildTitle(p.key, text, op.mark)
            endEventAt(ev, op.atMs ?? nowMs)
            writeDesc(ev, ref: op.ref ?? "", isOpen: false)
        }
        if findByRef(cal, op.newRef, hintMs: op.atMs) != nil { return }
        let at = op.atMs ?? nowMs
        let end = max(at + msMin, op.nowMs ?? 0)
        let ne = cal.createEvent(
            calendarId: Credentials.actualId,
            title: Grammar.buildTitle(op.newKey ?? "", "", nil),
            startMs: at, endMs: end
        )
        writeDesc(ne, ref: op.newRef ?? "", isOpen: true)
        applyCatColor(ne, op.newKey)
    }

    private static func opOpenSit(_ op: Op) {
        guard let cal = sitting else { return }
        if findByRef(cal, op.ref, hintMs: op.startMs) != nil { return }
        if let prev = findOpen(cal), refOf(prev) != op.ref {
            endEventAt(prev, op.startMs ?? nowMs)
            writeDesc(prev, ref: refOf(prev), isOpen: false)
        }
        let start = op.startMs ?? nowMs
        let ev = cal.createEvent(
            calendarId: Credentials.sittingId,
            title: TT.sitTitle, startMs: start, endMs: start + msMin
        )
        writeDesc(ev, ref: op.ref ?? "", isOpen: true)
    }

    private static func opCloseSit(_ op: Op) {
        guard let cal = sitting else { return }
        guard let ev = findByRef(cal, op.ref, hintMs: op.endMs) else { return }
        if !isOpen(ev) { return }
        ev.title = TT.sitTitle
        endEventAt(ev, op.endMs ?? nowMs)
        writeDesc(ev, ref: op.ref ?? "", isOpen: false)
    }

    private static func opSetSitStart(_ op: Op) {
        guard let cal = sitting else { return }
        guard let ev = findByRef(cal, op.ref, hintMs: op.startMs) else { return }
        let start = op.startMs ?? ev.startMs
        var end = ev.endMs
        if !(end > start) { end = start + msMin }
        ev.startMs = start
        ev.endMs = end
    }

    private static func opDeleteSit(_ op: Op) {
        guard let cal = sitting else { return }
        if let ev = findByRef(cal, op.ref, hintMs: op.hintMs) { cal.delete(ev) }
    }
}
