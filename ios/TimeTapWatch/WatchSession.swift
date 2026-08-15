import Combine
import Foundation
import WatchConnectivity

/// Watch-side WatchConnectivity. One session, no App Group.
final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    @Published var state = WatchState(
        openKey: nil,
        openFace: nil,
        openHex: nil,
        startMs: nil,
        distracted: false,
        distractedMs: 0,
        groups: []
    )

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ command: WatchCommand) {
        guard let data = try? JSONEncoder().encode(command) else { return }
        let payload = [WatchWire.commandKey: data]
        let session = WCSession.default
        session.sendMessage(payload, replyHandler: nil) { _ in
            session.transferUserInfo(payload)
        }
    }

    private func apply(_ info: [String: Any]) {
        guard let data = info[WatchWire.stateKey] as? Data,
              let next = try? JSONDecoder().decode(WatchState.self, from: data)
        else { return }
        state = next
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in self.apply(session.applicationContext) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }
}
