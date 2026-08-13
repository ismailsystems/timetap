import Foundation

struct CalendarSummary: Equatable, Identifiable {
    var id: String
    var summary: String
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
