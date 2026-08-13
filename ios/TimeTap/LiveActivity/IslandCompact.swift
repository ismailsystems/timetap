import SwiftUI

enum IslandCompact {
    @ViewBuilder
    static func islandBlock(
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
                    ElapsedTimer(range: range, size: timeSize, width: timeWidth, align: .leading)
                }
            }
            .frame(width: timeWidth, alignment: .leading)
            .clipped()
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }

    static func islandPosture(
        _ state: RunningBlockAttributes.ContentState,
        nameSize: CGFloat,
        timeSize: CGFloat,
        timeWidth: CGFloat
    ) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(verbatim: state.sitting ? "SITTING" : "NOT SITTING")
                .font(.system(size: nameSize, weight: .black))
                .foregroundStyle(Theme.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: timeWidth, alignment: .trailing)
            if let range = state.postureTimerRange {
                ElapsedTimer(range: range, size: timeSize, width: timeWidth, align: .trailing)
            }
        }
        .frame(width: timeWidth, alignment: .trailing)
        .clipped()
    }

    private static func faceLabel(_ face: String, size: CGFloat) -> some View {
        Text(verbatim: face.uppercased())
            .font(.system(size: size, weight: .black))
            .foregroundStyle(Theme.fg)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .truncationMode(.tail)
            .allowsTightening(true)
    }
}
