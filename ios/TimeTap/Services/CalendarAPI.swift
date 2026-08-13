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

enum CalendarAPI {
    static var testList: [CalendarSummary]?

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

    static func httpInsertPending() async throws {
        guard let event = lastPending else { return }
        guard let token = GoogleAuth.accessToken, !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        let enc = event.calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? event.calendarId
        var req = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(enc)/events")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let start = fmt.string(from: Date(timeIntervalSince1970: event.startMs / 1000))
        let end = fmt.string(from: Date(timeIntervalSince1970: event.endMs / 1000))
        let body: [String: Any] = [
            "summary": event.title,
            "description": event.description,
            "colorId": event.colorId,
            "start": ["dateTime": start],
            "end": ["dateTime": end]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CalendarAPIError.insertFailed
        }
        lastPending = nil
    }

    static func listCalendars() async throws -> [CalendarSummary] {
        if let testList { return testList }
        GoogleAuth.didFetchCalendarList = true
        guard let token = GoogleAuth.accessToken, !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
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
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
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
}
