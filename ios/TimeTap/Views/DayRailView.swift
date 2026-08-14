import SwiftUI

struct DayRailView: View {
    @EnvironmentObject private var store: TapStore
    let tick: Date
    var nowRowHeight: CGFloat = 44
    var onOpenTap: () -> Void = {}
    var onOtherTap: () -> Void = {}

    var body: some View {
        let _ = tick
        GeometryReader { geo in
            let now = store.clock()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(store.railItems(budget: 40, now: now).startLabel)
                            .font(Theme.font(11, weight: .bold))
                            .foregroundStyle(Theme.mute)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 6)
                        Text(store.syncLabel.uppercased())
                            .font(Theme.font(11, weight: .bold))
                            .foregroundStyle(store.syncFailed ? Theme.accentOn : Theme.mute)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.trailing)
                    }
                    GeometryReader { bodyGeo in
                        let rail = store.railItems(budget: max(bodyGeo.size.height, 40), now: now)
                        VStack(spacing: 0) {
                            ForEach(rail.items) { item in
                                block(item, railWidth: geo.size.width - 24)
                            }
                        }
                        .frame(width: bodyGeo.size.width, height: bodyGeo.size.height, alignment: .topLeading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Text("NOW ▲")
                    .font(Theme.font(11, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(Theme.accentOn)
                    .padding(.leading, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity, minHeight: nowRowHeight, maxHeight: nowRowHeight, alignment: .topLeading)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    private func block(_ item: TapStore.RailItem, railWidth: CGFloat) -> some View {
        let size = Self.labelSize(height: item.height, width: railWidth)
        let inline = Self.noteInline(height: item.height, hasNote: !item.note.isEmpty, size: size)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(item.name)
                    .font(Theme.font(size, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(1)
                if inline {
                    Text("·")
                        .font(Theme.font(size, weight: .bold))
                    Text(item.note)
                        .font(Theme.font(max(11, size * 0.85), weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Spacer(minLength: 0)
                Text(Format.shortElapsed(item.ms))
                    .font(Theme.font(size, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(1)
            }
            if !item.note.isEmpty, !inline {
                Text(item.note)
                    .font(Theme.font(max(11, size * 0.75), weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: item.height, alignment: item.note.isEmpty || inline ? .center : .topLeading)
        .foregroundStyle(item.isGap ? Theme.dim : Theme.onFill(item.hex ?? "#616161"))
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
            if item.isGap {
                Rectangle().strokeBorder(Theme.mute, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            } else if item.isOpen {
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
            ctx.stroke(path, with: .color(Theme.mute), lineWidth: 1)
        }
    }
}
