import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var store: TapStore
    @State private var errorText: String?
    @State private var busy = false

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("timetap")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Theme.fg)
                Text("TimeTap writes your PLAN, ACTUAL and SITTING calendars.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button(action: startSignIn) {
                    if busy {
                        ProgressView().tint(.white).padding(.vertical, 14)
                    } else {
                        Text("Sign in with Google")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .background(Theme.accent)
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .disabled(busy)
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
        busy = true
        Task {
            defer { busy = false }
            do {
                try await GoogleAuth.signInFromKeyWindow()
                await store.didSignIn()
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
