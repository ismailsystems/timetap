import SwiftUI

struct DayRailView: View {
    @EnvironmentObject private var store: TapStore
    let tick: Date

    var body: some View {
        let _ = tick
        GeometryReader { geo in
            let now = Date().timeIntervalSince1970 * 1000
            let rail = store.railItems(budget: max(geo.size.height - 44, 40), now: now)
            VStack(alignment: .leading, spacing: 6) {
                Text(rail.startLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.mute)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                VStack(spacing: 0) {
                    ForEach(rail.items) { item in
                        HStack(spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 9, weight: .bold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(Format.shortElapsed(item.ms))
                                .font(.system(size: 9, weight: .bold).monospacedDigit())
                        }
                        .padding(.horizontal, 6)
                        .frame(height: item.height, alignment: .center)
                        .foregroundStyle(item.isGap ? Theme.mute : .white)
                        .background {
                            if item.isGap {
                                GapFill()
                            } else if let hex = item.hex {
                                Theme.hex(hex)
                            } else {
                                Color.gray
                            }
                        }
                        .overlay {
                            if item.isOpen {
                                Rectangle().strokeBorder(Theme.fg, lineWidth: 2)
                            }
                        }
                        .clipped()
                    }
                }
            }
            .padding(12)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
    }
}

private struct GapFill: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.panel2))
            var path = Path()
            let step: CGFloat = 6
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += step
            }
            ctx.stroke(path, with: .color(Theme.rule2), lineWidth: 1)
        }
    }
}
