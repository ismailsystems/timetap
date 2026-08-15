import Foundation
import GoogleSignIn

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum GoogleAuth {
    static let calendarScope = "https://www.googleapis.com/auth/calendar"

    /// Test seam. `nil` means read the real Google Sign-In session.
    static var testHasSession: Bool?
    static var testAccessToken: String?
    static var lastSignInCancelled = false
    static var didFetchCalendarList = false
    static var didAttemptCalendarWrite = false
    static var refreshCount = 0

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
        do {
            #if canImport(UIKit)
            guard let presenting = topViewController() else { return }
            _ = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenting,
                hint: nil,
                additionalScopes: [calendarScope]
            )
            #elseif canImport(AppKit)
            guard let nsWindow = NSApp.keyWindow else { return }
            _ = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: nsWindow,
                hint: nil,
                additionalScopes: [calendarScope]
            )
            #endif
            followSDKSession()
            try requireCalendarScope()
        } catch {
            if isCancel(error) {
                applyCancelledSignIn()
            }
            throw error
        }
    }

    static func applyCancelledSignIn() {
        lastSignInCancelled = true
        followSDKSession()
        GIDSignIn.sharedInstance.signOut()
        // A2 owns calendar list. A3 owns writes. Cancel must do neither.
        didFetchCalendarList = false
        didAttemptCalendarWrite = false
    }

    static func signOut() {
        followSDKSession()
        GIDSignIn.sharedInstance.signOut()
    }

    static func restore(then done: @escaping () -> Void = {}) {
        GIDSignIn.sharedInstance.restorePreviousSignIn { _, _ in done() }
    }

    /// Production follows GID. Tests pin the seam with `testHasSession = true/false`.
    static func followSDKSession() {
        testHasSession = nil
        testAccessToken = nil
    }

    static func refreshAccessToken() async throws {
        refreshCount += 1
        if testHasSession != nil { return }
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw URLError(.userAuthenticationRequired)
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            user.refreshTokensIfNeeded { _, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
    }

    /// Tests pin `testHasSession` and count as granted. Live: missing calendar scope signs out.
    static func requireCalendarScope() throws {
        if testHasSession != nil { return }
        let granted = GIDSignIn.sharedInstance.currentUser?.grantedScopes ?? []
        if granted.contains(calendarScope) { return }
        signOut()
        throw CalendarHTTPError(status: 403, message: "Google Calendar access was not granted")
    }

    static func resetForTests() {
        testHasSession = false
        testAccessToken = nil
        lastSignInCancelled = false
        didFetchCalendarList = false
        didAttemptCalendarWrite = false
        refreshCount = 0
    }

    private static func isCancel(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == GIDSignInError.errorDomain
            && ns.code == GIDSignInError.canceled.rawValue
    }

    #if canImport(UIKit)
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
    #endif
}
