import SwiftUI

struct DayRailView: View {
    @EnvironmentObject private var store: TapStore
    let tick: Date
    var onOpenTap: () -> Void = {}
    var onOtherTap: () -> Void = {}

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
                        block(item, railWidth: geo.size.width - 24)
                    }
                }
            }
            .padding(12)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
    }

    private func block(_ item: TapStore.RailItem, railWidth: CGFloat) -> some View {
        let size = Self.labelSize(height: item.height, width: railWidth)
        let inline = Self.noteInline(height: item.height, hasNote: !item.note.isEmpty, size: size)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(item.name)
                    .font(.system(size: size, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(1)
                if inline {
                    Text("·")
                        .font(.system(size: size, weight: .bold))
                    Text(item.note)
                        .font(.system(size: max(11, size * 0.85), weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Spacer(minLength: 0)
                Text(Format.shortElapsed(item.ms))
                    .font(.system(size: size, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(1)
            }
            if !item.note.isEmpty, !inline {
                Text(item.note)
                    .font(.system(size: max(11, size * 0.75), weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: item.height, alignment: item.note.isEmpty || inline ? .center : .topLeading)
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
        .contentShape(Rectangle())
        .onTapGesture {
            if item.isOpen { onOpenTap() } else { onOtherTap() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(railLabel(item))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(item.isOpen ? "Edits the note" : "Hides the note field")
    }

    private func railLabel(_ item: TapStore.RailItem) -> String {
        var parts = [item.name]
        if !item.note.isEmpty { parts.append(item.note) }
        if item.isOpen { parts.append("open") }
        return parts.joined(separator: ", ")
    }

    /// Grows with block height and rail width; stays readable on a thin strip.
    static func labelSize(height: CGFloat, width: CGFloat) -> CGFloat {
        min(28, max(13, min(height * 0.42, width * 0.14)))
    }

    /// A short block cannot hold a second line, so the note sits after a middot.
    static func noteInline(height: CGFloat, hasNote: Bool, size: CGFloat) -> Bool {
        hasNote && height < max(36, size * 2.2)
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
