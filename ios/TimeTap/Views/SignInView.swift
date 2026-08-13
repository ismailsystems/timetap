import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var store: TapStore
    @State private var errorText: String?

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("timetap")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Theme.fg)
                Button(action: startSignIn) {
                    Text("Sign in with Google")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("googleSignIn")
                .padding(.horizontal, 32)
                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(Theme.accentOn)
                        .padding(.horizontal, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private func startSignIn() {
        errorText = nil
        Task {
            do {
                try await GoogleAuth.signInFromKeyWindow()
                await MainActor.run {
                    store.showSignIn = false
                    if !Credentials.hasCalendarIds {
                        store.showPicker = true
                    }
                }
            } catch {
                await MainActor.run {
                    if GoogleAuth.lastSignInCancelled {
                        errorText = nil
                    } else {
                        errorText = error.localizedDescription
                    }
                }
            }
        }
    }
}
