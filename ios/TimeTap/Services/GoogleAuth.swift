import Foundation
import GoogleSignIn
import UIKit

enum GoogleAuth {
    static let calendarScope = "https://www.googleapis.com/auth/calendar"

    /// Test seam. `nil` means read the real Google Sign-In session.
    static var testHasSession: Bool?
    static var testAccessToken: String?
    static var lastSignInCancelled = false
    static var didFetchCalendarList = false
    static var didAttemptCalendarWrite = false

    static var hasSession: Bool {
        if let testHasSession { return testHasSession }
        return GIDSignIn.sharedInstance.currentUser != nil
    }

    static var accessToken: String? {
        if testHasSession != nil { return testAccessToken }
        return GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString
    }

    static func configure() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty
        else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    static func handleURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    @MainActor
    static func signInFromKeyWindow() async throws {
        lastSignInCancelled = false
        guard let presenting = topViewController() else { return }
        do {
            _ = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenting,
                hint: nil,
                additionalScopes: [calendarScope]
            )
        } catch {
            if isCancel(error) {
                applyCancelledSignIn()
            }
            throw error
        }
    }

    static func applyCancelledSignIn() {
        lastSignInCancelled = true
        testHasSession = false
        testAccessToken = nil
        GIDSignIn.sharedInstance.signOut()
        // A2 owns calendar list. A3 owns writes. Cancel must do neither.
        didFetchCalendarList = false
        didAttemptCalendarWrite = false
    }

    static func restore() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { _, _ in }
    }

    static func resetForTests() {
        testHasSession = false
        testAccessToken = nil
        lastSignInCancelled = false
        didFetchCalendarList = false
        didAttemptCalendarWrite = false
    }

    private static func isCancel(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == GIDSignInError.errorDomain
            && ns.code == GIDSignInError.canceled.rawValue
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let root = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
            ?? scenes.flatMap(\.windows).first?.rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
