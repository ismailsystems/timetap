import Foundation

struct CalendarSummary: Equatable, Identifiable {
    var id: String
    var summary: String
}

final class CalEvent: Equatable {
    var id: String
    var calendarId: String
    var key: String
    var title: String
    var colorId: String
    var description: String
    var startMs: Double
    var endMs: Double
    var isAllDay: Bool

    init(
        id: String, calendarId: String, key: String, title: String,
        colorId: String, description: String, startMs: Double, endMs: Double,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.calendarId = calendarId
        self.key = key
        self.title = title
        self.colorId = colorId
        self.description = description
        self.startMs = startMs
        self.endMs = endMs
        self.isAllDay = isAllDay
    }

    static func == (lhs: CalEvent, rhs: CalEvent) -> Bool {
        lhs.id == rhs.id && lhs.calendarId == rhs.calendarId && lhs.key == rhs.key
            && lhs.title == rhs.title && lhs.colorId == rhs.colorId
            && lhs.description == rhs.description && lhs.startMs == rhs.startMs
            && lhs.endMs == rhs.endMs && lhs.isAllDay == rhs.isAllDay
    }
}

final class FakeCalendar {
    var events: [CalEvent] = []
    var failInsert = false
    var lastCalendarId: String?

    func insert(_ event: CalEvent) throws {
        lastCalendarId = event.calendarId
        if failInsert { throw CalendarAPIError.insertFailed }
        events.append(event)
    }

    func events(from lo: Double, to hi: Double) -> [CalEvent] {
        events.filter { !$0.isAllDay && $0.endMs > lo && $0.startMs < hi }
            .sorted { $0.startMs < $1.startMs }
    }

    func createEvent(calendarId: String, title: String, startMs: Double, endMs: Double) -> CalEvent {
        lastCalendarId = calendarId
        let ev = CalEvent(
            id: Op.uid(), calendarId: calendarId, key: "", title: title,
            colorId: "", description: "", startMs: startMs, endMs: endMs
        )
        events.append(ev)
        return ev
    }

    func delete(_ ev: CalEvent) {
        events.removeAll { $0 === ev || $0.id == ev.id }
    }
}

enum CalendarAPIError: Error {
    case calendarsNotPicked
    case insertFailed
}

struct CalendarHTTPError: Error, LocalizedError {
    var status: Int
    var message: String? = nil

    var errorDescription: String? {
        if let message, !message.isEmpty { return "HTTP \(status): \(message)" }
        return "HTTP \(status)"
    }
}

enum CalendarAPI {
    /// One list/apply/push at a time. `await body()` leaves the actor (SE-0338),
    /// so `busy` stays set across the awaits and the next caller waits.
    private actor Serial {
        private var busy = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func run<T>(_ body: () async throws -> T) async throws -> T {
            while busy {
                await withCheckedContinuation { waiters.append($0) }
            }
            busy = true
            defer {
                busy = false
                if !waiters.isEmpty {
                    waiters.removeFirst().resume()
                }
            }
            return try await body()
        }
    }
    private static let serial = Serial()

    static var testList: [CalendarSummary]?
    static var testStatusQueue: [Int] = []
    static var rejectWrites = false
    static var getStateCalls = 0
    static var didFlush = false
    static var testListedActual: FakeCalendar?
    static var testListedSitting: FakeCalendar?
    static var skipStatePush = false
    static var didPushState = false
    static var testStateError: String?
    static var testListedByCal: [String: [CalEvent]]?
    static var testPushes: [(method: String, calendarId: String, eventId: String?, summary: String)] = []
    static var didStaleClose = false

    static func resetTestHTTP() {
        testStatusQueue = []
        rejectWrites = false
        getStateCalls = 0
        didFlush = false
        testListedActual = nil
        testListedSitting = nil
        skipStatePush = false
        didPushState = false
        testStateError = nil
        testListedByCal = nil
        testPushes = []
        didStaleClose = false
    }

    static func firstMatch(named name: String, in list: [CalendarSummary]) -> CalendarSummary? {
        list.first { $0.summary == name }
    }

    static func preselect(_ list: [CalendarSummary]) -> (plan: String?, actual: String?, sitting: String?) {
        (
            firstMatch(named: "PLAN", in: list)?.id,
            firstMatch(named: "ACTUAL", in: list)?.id,
            firstMatch(named: "SITTING", in: list)?.id
        )
    }

    static func canConfirm(plan: String?, actual: String?, sitting: String?) -> Bool {
        func filled(_ s: String?) -> Bool { !(s ?? "").isEmpty }
        return filled(plan) && filled(actual) && filled(sitting)
    }

    static func confirm(plan: String?, actual: String?, sitting: String?) -> Bool {
        guard canConfirm(plan: plan, actual: actual, sitting: sitting) else { return false }
        Credentials.planId = plan ?? ""
        Credentials.actualId = actual ?? ""
        Credentials.sittingId = sitting ?? ""
        return true
    }

    struct Pick: Equatable {
        var list: [CalendarSummary]
        var planId: String?
        var actualId: String?
        var sittingId: String?

        static func loaded(_ list: [CalendarSummary]) -> Pick {
            let pre = CalendarAPI.preselect(list)
            return Pick(list: list, planId: pre.plan, actualId: pre.actual, sittingId: pre.sitting)
        }

        static func fromSaved(_ list: [CalendarSummary]) -> Pick {
            if Credentials.hasCalendarIds {
                return Pick(
                    list: list,
                    planId: Credentials.planId,
                    actualId: Credentials.actualId,
                    sittingId: Credentials.sittingId
                )
            }
            return loaded(list)
        }

        var canConfirm: Bool {
            CalendarAPI.canConfirm(plan: planId, actual: actualId, sitting: sittingId)
        }

        var emptyLabel: String? {
            list.isEmpty ? "No calendars" : nil
        }

        var firstMatchRule: String {
            "If two calendars share a name, the first one in the list is used."
        }
    }

    static var testCalendar: FakeCalendar?
    static var lastPending: CalEvent?

    static func openActual(key: String, at t: Double, ref: String) throws -> CalEvent {
        guard !Credentials.actualId.isEmpty else {
            throw CalendarAPIError.calendarsNotPicked
        }
        let event = CalEvent(
            id: ref,
            calendarId: Credentials.actualId,
            key: key,
            title: "\(key):",
            colorId: Grammar.colorId(for: key),
            description: "#ref:\(ref)\n#open",
            startMs: t,
            endMs: t + 60_000
        )
        lastPending = event
        GoogleAuth.didAttemptCalendarWrite = true
        if let testCalendar {
            try testCalendar.insert(event)
            lastPending = nil
        }
        return event
    }

    static func retryLastInsert() throws {
        guard let pending = lastPending else { return }
        _ = try openActual(key: pending.key, at: pending.startMs, ref: pending.id)
    }

    static func listCalendars() async throws -> [CalendarSummary] {
        if let testList { return testList }
        GoogleAuth.didFetchCalendarList = true
        guard let token = GoogleAuth.accessToken, !token.isEmpty else {
            throw CalendarHTTPError(status: 401)
        }
        var out: [CalendarSummary] = []
        var page: String?
        repeat {
            var comps = URLComponents(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
            var q = [URLQueryItem(name: "maxResults", value: "250")]
            if let page { q.append(URLQueryItem(name: "pageToken", value: page)) }
            comps.queryItems = q
            var req = URLRequest(url: comps.url!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if !(200..<300).contains(status) {
                throw googleError(status: status, data: data)
            }
            let decoded = try JSONDecoder().decode(ListPage.self, from: data)
            for item in decoded.items ?? [] {
                out.append(CalendarSummary(id: item.id, summary: item.summary ?? ""))
            }
            page = decoded.nextPageToken
        } while page != nil
        return out
    }

    private struct ListPage: Decodable {
        var items: [Item]?
        var nextPageToken: String?
        struct Item: Decodable {
            var id: String
            var summary: String?
        }
    }

    /// List ACTUAL + SITTING, run getState (staleGuard mutates), push the diff.
    static func refreshState() async throws -> ServerState {
        try await serial.run { try await refreshStateBody() }
    }

    private static func refreshStateBody() async throws -> ServerState {
        getStateCalls += 1
        if let testStateError {
            throw ApplyOps.ReadError.calendar(testStateError)
        }
        if let s = dequeueStatus(), s != 200 {
            throw CalendarHTTPError(status: s)
        }
        if let listed = testListedActual {
            ApplyOps.actual = cloneCalendar(listed)
            ApplyOps.sitting = cloneCalendar(testListedSitting ?? FakeCalendar())
            let beforeA = (ApplyOps.actual?.events ?? []).map(copyEvent)
            let st = try ApplyOps.getState()
            noteStaleClose(before: beforeA, after: ApplyOps.actual?.events ?? [])
            if !skipStatePush {
                listed.events = (ApplyOps.actual?.events ?? []).map(copyEvent)
                testListedSitting?.events = (ApplyOps.sitting?.events ?? []).map(copyEvent)
                didPushState = true
            }
            return st
        }
        if GoogleAuth.testHasSession != nil {
            return try ApplyOps.getState()
        }
        guard let token = GoogleAuth.accessToken, !token.isEmpty else {
            throw CalendarHTTPError(status: 401)
        }
        ApplyOps.timeZone = TimeZone.current
        let now = Date().timeIntervalSince1970 * 1000
        let lo = now - 72 * 3_600_000
        let hi = now + 24 * 3_600_000
        let actual = FakeCalendar()
        let sitting = FakeCalendar()
        actual.events = try await listEvents(calendarId: Credentials.actualId, from: lo, to: hi, token: token)
        sitting.events = try await listEvents(calendarId: Credentials.sittingId, from: lo, to: hi, token: token)
        let beforeA = actual.events.map(copyEvent)
        let beforeS = sitting.events.map(copyEvent)
        ApplyOps.actual = actual
        ApplyOps.sitting = sitting
        ApplyOps.nowMs = now
        let st = try ApplyOps.getState()
        noteStaleClose(before: beforeA, after: actual.events)
        if !skipStatePush {
            try await pushDiff(calendarId: Credentials.actualId, before: beforeA, after: actual.events, token: token)
            try await pushDiff(calendarId: Credentials.sittingId, before: beforeS, after: sitting.events, token: token)
            didPushState = true
        }
        return st
    }

    /// Queue flush. Tests never hit the network (`GoogleAuth.testHasSession != nil`).
    static func flushOps(_ ops: [Op]) async throws -> ApplyResult {
        try await serial.run { try await flushOpsBody(ops) }
    }

    private static func flushOpsBody(_ ops: [Op]) async throws -> ApplyResult {
        didFlush = true
        if let s = dequeueStatus(), s != 200 {
            throw CalendarHTTPError(status: s)
        }
        if rejectWrites {
            return ApplyResult(
                applied: [],
                errors: [.init(id: ops.first?.id, message: "insert failed")],
                dropped: []
            )
        }
        if testListedByCal != nil {
            return try await liveFlush(ops)
        }
        if GoogleAuth.testHasSession != nil {
            if ApplyOps.actual == nil { ApplyOps.actual = testCalendar ?? FakeCalendar() }
            if ApplyOps.sitting == nil { ApplyOps.sitting = FakeCalendar() }
            return ApplyOps.apply(ops)
        }
        return try await liveFlush(ops)
    }

    private static func dequeueStatus() -> Int? {
        guard !testStatusQueue.isEmpty else { return nil }
        return testStatusQueue.removeFirst()
    }

    private static func liveFlush(_ ops: [Op]) async throws -> ApplyResult {
        let seamed = testListedByCal != nil
        let token = GoogleAuth.accessToken ?? ""
        if !seamed, token.isEmpty {
            throw CalendarHTTPError(status: 401)
        }
        if !seamed {
            ApplyOps.timeZone = TimeZone.current
            ApplyOps.nowMs = Date().timeIntervalSince1970 * 1000
        }
        let now = ApplyOps.nowMs
        let lo = now - 72 * 3_600_000
        let hi = now + 24 * 3_600_000
        let actual = FakeCalendar()
        let sitting = FakeCalendar()
        actual.events = try await listEvents(calendarId: Credentials.actualId, from: lo, to: hi, token: token)
        sitting.events = try await listEvents(calendarId: Credentials.sittingId, from: lo, to: hi, token: token)
        let beforeA = actual.events.map(copyEvent)
        let beforeS = sitting.events.map(copyEvent)
        ApplyOps.actual = actual
        ApplyOps.sitting = sitting
        let result = ApplyOps.apply(ops)
        try await pushDiff(calendarId: Credentials.actualId, before: beforeA, after: actual.events, token: token)
        try await pushDiff(calendarId: Credentials.sittingId, before: beforeS, after: sitting.events, token: token)
        return result
    }

    private static func noteStaleClose(before: [CalEvent], after: [CalEvent]) {
        guard before.contains(where: { $0.description.contains("#open") }) else { return }
        let openGone = !after.contains { $0.description.contains("#open") }
        let guess = after.contains { $0.title.hasSuffix("?") }
        if openGone, guess { didStaleClose = true }
    }

    private static func copyEvent(_ e: CalEvent) -> CalEvent {
        CalEvent(
            id: e.id, calendarId: e.calendarId, key: e.key, title: e.title,
            colorId: e.colorId, description: e.description, startMs: e.startMs,
            endMs: e.endMs, isAllDay: e.isAllDay
        )
    }

    private static func cloneCalendar(_ cal: FakeCalendar) -> FakeCalendar {
        let copy = FakeCalendar()
        copy.events = cal.events.map(copyEvent)
        copy.failInsert = cal.failInsert
        copy.lastCalendarId = cal.lastCalendarId
        return copy
    }

    private static func listEvents(calendarId: String, from lo: Double, to hi: Double, token: String) async throws -> [CalEvent] {
        if let listed = testListedByCal {
            return (listed[calendarId] ?? []).map(copyEvent).filter {
                !$0.isAllDay && $0.endMs > lo && $0.startMs < hi
            }.sorted { $0.startMs < $1.startMs }
        }
        var out: [CalEvent] = []
        var page: String?
        repeat {
            var comps = URLComponents()
            comps.scheme = "https"
            comps.host = "www.googleapis.com"
            comps.percentEncodedPath = "/calendar/v3/calendars/\(enc(calendarId))/events"
            var q = [
                URLQueryItem(name: "timeMin", value: rfc3339(lo)),
                URLQueryItem(name: "timeMax", value: rfc3339(hi)),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "maxResults", value: "250"),
            ]
            if let page { q.append(URLQueryItem(name: "pageToken", value: page)) }
            comps.queryItems = q
            var req = URLRequest(url: comps.url!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if !(200..<300).contains(status) {
                throw googleError(status: status, data: data)
            }
            let decoded = try JSONDecoder().decode(EventsPage.self, from: data)
            for item in decoded.items ?? [] {
                let allDay = item.start.date != nil
                if allDay { continue }
                guard let start = parseWhen(item.start), let end = parseWhen(item.end) else { continue }
                out.append(CalEvent(
                    id: item.id, calendarId: calendarId, key: "",
                    title: item.summary ?? "", colorId: item.colorId ?? "",
                    description: item.description ?? "", startMs: start, endMs: end,
                    isAllDay: false
                ))
            }
            page = decoded.nextPageToken
        } while page != nil
        return out
    }

    private static func pushDiff(calendarId: String, before: [CalEvent], after: [CalEvent], token: String) async throws {
        let beforeById = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0) })
        let afterIds = Set(after.map(\.id))
        for old in before where !afterIds.contains(old.id) {
            try await http("DELETE", calendarId: calendarId, eventId: old.id, body: nil, token: token)
        }
        for ev in after {
            if let old = beforeById[ev.id] {
                if old != ev {
                    try await http("PATCH", calendarId: calendarId, eventId: ev.id, body: eventBody(ev), token: token)
                }
            } else {
                if let gid = try await http("POST", calendarId: calendarId, eventId: nil, body: eventBody(ev), token: token) {
                    ev.id = gid
                }
            }
        }
    }

    static func eventBody(_ ev: CalEvent) -> [String: Any] {
        var body: [String: Any] = [
            "summary": ev.title,
            "description": ev.description,
            "start": ["dateTime": rfc3339(ev.startMs)],
            "end": ["dateTime": rfc3339(ev.endMs)],
        ]
        if (1...11).contains(Int(ev.colorId) ?? 0) {
            body["colorId"] = ev.colorId
        }
        return body
    }

    @discardableResult
    private static func http(_ method: String, calendarId: String, eventId: String?, body: [String: Any]?, token: String) async throws -> String? {
        if testListedByCal != nil {
            testPushes.append((
                method: method,
                calendarId: calendarId,
                eventId: eventId,
                summary: body?["summary"] as? String ?? ""
            ))
            return nil
        }
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "www.googleapis.com"
        var path = "/calendar/v3/calendars/\(enc(calendarId))/events"
        if let eventId { path += "/\(enc(eventId))" }
        comps.percentEncodedPath = path
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if method == "DELETE", status == 404 || status == 410 { return nil }
        if !(200..<300).contains(status) {
            throw googleError(status: status, data: data)
        }
        if method == "POST" { return createdEventId(from: data) }
        return nil
    }

    static func createdEventId(from data: Data) -> String? {
        struct Created: Decodable { var id: String? }
        return (try? JSONDecoder().decode(Created.self, from: data))?.id
    }

    /// RFC 3986 unreserved. `@` in a calendar id must be `%40` or Google returns 400.
    static func enc(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    static func rfc3339(_ ms: Double) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }

    static func googleError(status: Int, data: Data) -> CalendarHTTPError {
        struct Envelope: Decodable {
            struct Body: Decodable { var message: String? }
            var error: Body?
        }
        let msg = (try? JSONDecoder().decode(Envelope.self, from: data))?.error?.message
        return CalendarHTTPError(status: status, message: msg)
    }

    private static func parseWhen(_ w: EventsPage.Item.When) -> Double? {
        if let dt = w.dateTime {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: dt) { return d.timeIntervalSince1970 * 1000 }
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: dt) { return d.timeIntervalSince1970 * 1000 }
        }
        if let day = w.date {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyy-MM-dd"
            if let d = f.date(from: day) { return d.timeIntervalSince1970 * 1000 }
        }
        return nil
    }

    private struct EventsPage: Decodable {
        var items: [Item]?
        var nextPageToken: String?
        struct Item: Decodable {
            var id: String
            var summary: String?
            var description: String?
            var colorId: String?
            var start: When
            var end: When
            struct When: Decodable {
                var dateTime: String?
                var date: String?
            }
        }
    }
}
