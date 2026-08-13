import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct RunningBlockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunningBlockAttributes.self) { context in
            lockScreen(context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    islandBlock(context.state, nameSize: 12, timeSize: 16, timeWidth: 78)
                        .padding(.leading, 10)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    islandPosture(context.state, nameSize: 12, timeSize: 16, timeWidth: 78)
                        .padding(.trailing, 10)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        if context.state.hasBlock {
                            blockStop
                        }
                        sittingRow(context.state, compact: true)
                    }
                    .padding(.horizontal, 10)
                }
            } compactLeading: {
                islandBlock(context.state, nameSize: 10, timeSize: 12, timeWidth: 54)
                    .padding(.leading, 8)
            } compactTrailing: {
                islandPosture(context.state, nameSize: 10, timeSize: 12, timeWidth: 54)
                    .padding(.trailing, 8)
            } minimal: {
                if context.state.hasBlock {
                    categorySwatch(context.state.hex, size: 12, sitting: context.state.sitting)
                } else {
                    postureIcon(sitting: context.state.sitting, size: 12)
                }
            }
        }
    }

    private func lockScreen(_ state: RunningBlockAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.hasBlock {
                HStack(alignment: .center, spacing: 10) {
                    categoryBar(state.hex, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        faceLabel(state.face ?? "", size: 15)
                        if let range = state.timerRange {
                            elapsed(range, size: 26, width: 124, align: .leading)
                        }
                    }
                    Spacer(minLength: 8)
                    blockStop
                }
            }
            sittingRow(state, compact: false)
        }
        .padding(12)
        .activityBackgroundTint(Theme.ground)
        .activitySystemActionForegroundColor(Theme.fg)
    }

    private var blockStop: some View {
        Button(intent: StopBlockIntent()) {
            Text("STOP")
                .font(.system(size: 13, weight: .heavy))
        }
        .tint(Theme.accent)
        .accessibilityLabel("Stop the running block")
        .accessibilityHint("Does not stop sitting")
    }

    @ViewBuilder
    private func islandBlock(
        _ state: RunningBlockAttributes.ContentState,
        nameSize: CGFloat,
        timeSize: CGFloat,
        timeWidth: CGFloat
    ) -> some View {
        if state.hasBlock {
            VStack(alignment: .leading, spacing: 0) {
                faceLabel(state.face ?? "", size: nameSize)
                    .frame(width: timeWidth, alignment: .leading)
                if let range = state.timerRange {
                    elapsed(range, size: timeSize, width: timeWidth, align: .leading)
                }
            }
            .frame(width: timeWidth, alignment: .leading)
            .clipped()
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }

    private func islandPosture(
        _ state: RunningBlockAttributes.ContentState,
        nameSize: CGFloat,
        timeSize: CGFloat,
        timeWidth: CGFloat
    ) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(verbatim: state.sitting ? "SITTING" : "STANDING")
                .font(.system(size: nameSize, weight: .black))
                .foregroundStyle(Theme.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: timeWidth, alignment: .trailing)
            if let range = state.postureTimerRange {
                elapsed(range, size: timeSize, width: timeWidth, align: .trailing)
            }
        }
        .frame(width: timeWidth, alignment: .trailing)
        .clipped()
    }

    private func sittingRow(_ state: RunningBlockAttributes.ContentState, compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            postureIcon(sitting: state.sitting, size: compact ? 18 : 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: state.sitting ? "SITTING" : "NOT SITTING")
                    .font(.system(size: compact ? 12 : 13, weight: .black))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                if let range = state.postureTimerRange {
                    elapsed(range, size: compact ? 16 : 20, width: compact ? 72 : 96, align: .leading)
                }
            }
            Spacer(minLength: 8)
            if state.sitting {
                Button(intent: StopSitIntent()) {
                    Text("STOP")
                        .font(.system(size: 13, weight: .heavy))
                }
                .tint(Theme.accent)
                .accessibilityLabel("Stop sitting")
                .accessibilityHint("Does not stop the running block")
            } else {
                Button(intent: ToggleSitIntent()) {
                    Text("START")
                        .font(.system(size: 13, weight: .heavy))
                }
                .tint(Theme.fg)
                .accessibilityLabel("Start sitting")
                .accessibilityHint("Does not stop the running block")
            }
        }
    }

    private func faceLabel(_ face: String, size: CGFloat) -> some View {
        Text(verbatim: face.uppercased())
            .font(.system(size: size, weight: .black))
            .foregroundStyle(Theme.fg)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .truncationMode(.tail)
            .allowsTightening(true)
    }

    private func elapsed(
        _ range: ClosedRange<Date>,
        size: CGFloat,
        width: CGFloat,
        align: Alignment
    ) -> some View {
        ElapsedTimer(range: range, size: size, width: width, align: align)
    }

    private func categoryBar(_ hex: String?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Theme.hex(hex ?? "#616161"))
            .frame(width: 8, height: height)
    }

    private func categorySwatch(_ hex: String?, size: CGFloat, sitting: Bool) -> some View {
        RoundedRectangle(cornerRadius: max(3, size * 0.22), style: .continuous)
            .fill(Theme.hex(hex ?? "#616161"))
            .frame(width: size, height: size)
            .overlay {
                if sitting {
                    RoundedRectangle(cornerRadius: max(3, size * 0.22), style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 2)
                }
            }
    }

    private func postureIcon(sitting: Bool, size: CGFloat) -> some View {
        Image(systemName: Theme.postureSymbol(sitting: sitting))
            .font(.system(size: max(12, size * 0.9), weight: .semibold))
            .foregroundStyle(Theme.fg)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
