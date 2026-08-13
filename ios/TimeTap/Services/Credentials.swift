import Foundation

enum Credentials {
    private static let planKey = "calendarPlanId"
    private static let actualKey = "calendarActualId"
    private static let sittingKey = "calendarSittingId"

    static var planId: String {
        get { UserDefaults.standard.string(forKey: planKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: planKey) }
    }

    static var actualId: String {
        get { UserDefaults.standard.string(forKey: actualKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: actualKey) }
    }

    static var sittingId: String {
        get { UserDefaults.standard.string(forKey: sittingKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: sittingKey) }
    }

    static var hasCalendarIds: Bool {
        !planId.isEmpty && !actualId.isEmpty && !sittingId.isEmpty
    }

    static var isConfigured: Bool {
        GoogleAuth.hasSession && hasCalendarIds
    }

    static func resetForTests() {
        planId = ""
        actualId = ""
        sittingId = ""
        GoogleAuth.resetForTests()
        CalendarAPI.testCalendar = nil
        CalendarAPI.testList = nil
        CalendarAPI.lastPending = nil
        CalendarAPI.resetTestHTTP()
        Grammar.extraColors = [:]
        ApplyOps.resetForTests()
        for key in ["tt.queue.v1", "tt.state.v1", "tt.dead.v1", "tt.blocks.v1", "tt.config.v1"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
