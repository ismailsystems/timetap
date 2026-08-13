import Foundation
import Security

enum Credentials {
    private static let service = "app.timetap.ios"
    private static let urlKey = "apiURL"
    private static let tokenAccount = "apiToken"
    private static let planKey = "calendarPlanId"
    private static let actualKey = "calendarActualId"
    private static let sittingKey = "calendarSittingId"

    static var apiURL: String {
        get { UserDefaults.standard.string(forKey: urlKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: urlKey) }
    }

    /// DEBUG-only UserDefaults mirror so `simctl` can inject a token for E2E.
    private static let debugTokenKey = "apiTokenDebug"

    static var apiToken: String {
        get {
            if let keychain = readKeychain(), !keychain.isEmpty { return keychain }
            #if DEBUG
            return UserDefaults.standard.string(forKey: debugTokenKey) ?? ""
            #else
            return ""
            #endif
        }
        set {
            if newValue.isEmpty {
                deleteKeychain()
                #if DEBUG
                UserDefaults.standard.removeObject(forKey: debugTokenKey)
                #endif
            } else {
                writeKeychain(newValue)
                #if DEBUG
                UserDefaults.standard.set(newValue, forKey: debugTokenKey)
                #endif
            }
        }
    }

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
        for key in ["tt.queue.v1", "tt.state.v1", "tt.dead.v1", "tt.blocks.v1", "tt.config.v1"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func writeKeychain(_ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
