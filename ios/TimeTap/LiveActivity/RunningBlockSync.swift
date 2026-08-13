import ActivityKit
import Foundation

enum LiveActivityRunState: Sendable, Equatable {
    case active
    case stale
    case dismissed
    case ended
}

protocol LiveActivityRuntime: Sendable {
    var areEnabled: Bool { get }
    func currentActivities() -> [(id: String, state: LiveActivityRunState)]
    func update(id: String, state: RunningBlockAttributes.ContentState) async
    func end(id: String) async
    func request(_ state: RunningBlockAttributes.ContentState) async throws
}

struct ActivityKitLiveActivityRuntime: LiveActivityRuntime {
    var areEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func currentActivities() -> [(id: String, state: LiveActivityRunState)] {
        Activity<RunningBlockAttributes>.activities.map { current in
            (id: current.id, state: LiveActivityRunState(current.activityState))
        }
    }

    func update(id: String, state: RunningBlockAttributes.ContentState) async {
        guard let current = Activity<RunningBlockAttributes>.activities.first(where: { $0.id == id }) else {
            return
        }
        let content = ActivityContent(state: state, staleDate: nil)
        await current.update(content)
    }

    func end(id: String) async {
        guard let extra = Activity<RunningBlockAttributes>.activities.first(where: { $0.id == id }) else {
            return
        }
        await extra.end(nil, dismissalPolicy: .immediate)
    }

    func request(_ state: RunningBlockAttributes.ContentState) async throws {
        let content = ActivityContent(state: state, staleDate: nil)
        _ = try await Activity.request(
            attributes: RunningBlockAttributes(),
            content: content,
            pushType: nil
        )
    }
}

private extension LiveActivityRunState {
    init(_ state: ActivityState) {
        switch state {
        case .active: self = .active
        case .stale: self = .stale
        case .dismissed: self = .dismissed
        case .ended: self = .ended
        @unknown default: self = .ended
        }
    }
}

enum RunningBlockSync {
    nonisolated(unsafe) static var runtime: any LiveActivityRuntime = ActivityKitLiveActivityRuntime()

    static func apply(_ state: RunningBlockAttributes.ContentState?) async {
        await apply(state, runtime: runtime)
    }

    static func apply(
        _ state: RunningBlockAttributes.ContentState?,
        runtime: any LiveActivityRuntime
    ) async {
        guard runtime.areEnabled else { return }
        if let state {
            let existing = runtime.currentActivities()
            if let current = existing.first,
               current.state == .active || current.state == .stale {
                await runtime.update(id: current.id, state: state)
                for extra in existing.dropFirst() {
                    await runtime.end(id: extra.id)
                }
            } else {
                for extra in existing {
                    await runtime.end(id: extra.id)
                }
                do {
                    try await runtime.request(state)
                } catch {
                    try? await runtime.request(state)
                }
            }
        } else {
            for activity in runtime.currentActivities() {
                await runtime.end(id: activity.id)
            }
        }
    }
}
