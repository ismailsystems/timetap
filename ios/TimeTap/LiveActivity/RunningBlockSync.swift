import ActivityKit
import Foundation

enum RunningBlockSync {
    static func apply(_ state: RunningBlockAttributes.ContentState?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let state {
            let content = ActivityContent(state: state, staleDate: nil)
            let existing = Activity<RunningBlockAttributes>.activities
            if let current = existing.first,
               current.activityState == .active || current.activityState == .stale {
                await current.update(content)
                for extra in existing.dropFirst() {
                    await extra.end(nil, dismissalPolicy: .immediate)
                }
            } else {
                for extra in existing {
                    await extra.end(nil, dismissalPolicy: .immediate)
                }
                do {
                    _ = try await Activity.request(
                        attributes: RunningBlockAttributes(),
                        content: content,
                        pushType: nil
                    )
                } catch {
                    _ = try? await Activity.request(
                        attributes: RunningBlockAttributes(),
                        content: content,
                        pushType: nil
                    )
                }
            }
        } else {
            for activity in Activity<RunningBlockAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
