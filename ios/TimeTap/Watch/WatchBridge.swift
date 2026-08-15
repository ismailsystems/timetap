import Combine
import WatchConnectivity

/// iPhone-side WatchConnectivity. One session, one store, no App Group.
@MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    static func start(store: TapStore) {
        shared.attach(store)
    }

    func pushState() {
        guard let store, WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let state = Self.state(from: store)
        guard state != last, let data = try? JSONEncoder().encode(state) else { return }
        last = state
        try? session.updateApplicationContext([WatchWire.stateKey: data])
        if session.isReachable {
            session.sendMessage([WatchWire.stateKey: data], replyHandler: nil) { _ in }
        }
    }

    private static let shared = WatchBridge()
    private var store: TapStore?
    private var sub: AnyCancellable?
    private var pushTask: Task<Void, Never>?
    private var last: WatchState?

    private func attach(_ store: TapStore) {
        self.store = store
        sub = store.objectWillChange.sink { [weak self] _ in
            self?.schedulePush()
        }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func schedulePush() {
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            self?.pushState()
        }
    }

    private static func state(from store: TapStore) -> WatchState {
        let open = store.open
        return WatchState(
            openKey: open?.key,
            openFace: open.map { store.labelFor($0.key) },
            openHex: open.flatMap { hex(for: $0.key, in: store.groups) },
            startMs: open?.startMs,
            distracted: store.distracted,
            distractedMs: store.currentDistractedMs(),
            groups: store.groups.map { g in
                WatchGroup(
                    label: g.label,
                    hex: g.hex,
                    children: g.children.map { WatchChild(label: $0.label, hex: $0.hex) }
                )
            }
        )
    }

    private static func hex(for key: String, in groups: [CategoryGroup]) -> String? {
        groups.lazy.flatMap(\.children).first { $0.label == key }?.hex
    }

    private func apply(_ info: [String: Any]) {
        guard let store,
              let data = info[WatchWire.commandKey] as? Data,
              let cmd = try? JSONDecoder().decode(WatchCommand.self, from: data)
        else { return }
        switch cmd {
        case .propose(let key): store.propose(key)
        case .toggleDistract: store.toggleDistract()
        case .endDay: store.endDay()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.last = nil
            self.pushState()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.last = nil
            self.pushState()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            self.apply(message)
            replyHandler([:])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.apply(userInfo) }
    }
}
