import SwiftUI

struct SplitSheet: View {
    @EnvironmentObject private var store: TapStore

    var body: some View {
        if let s = store.split, let open = store.open {
            let span = max(1, Int(((s.nowMs - s.startMs) / 60_000).rounded()))
            let maxMins = max(1, span - 1)
            let mins = max(1, Int(((s.atMs - s.startMs) / 60_000).rounded()))
            let range = TapStore.splitSliderRange(startMs: s.startMs, nowMs: s.nowMs)
            let value = min(max(Double(mins), range.lowerBound), range.upperBound)

            VStack(spacing: 0) {
                sheetHeader(
                    title: "OPEN BLOCK · \(store.labelFor(open.key).uppercased())",
                    close: { store.split = nil }
                )

                HStack(spacing: 0) {
                    scopeBtn("REMAINDER", on: !s.whole) { store.setSplitWhole(false) }
                        .disabled(maxMins < 2)
                    scopeBtn("WHOLE BLOCK", on: s.whole) { store.setSplitWhole(true) }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(Format.clock(s.startMs)).foregroundStyle(Theme.dim)
                        Spacer()
                        Text(Format.clock(s.atMs))
                            .foregroundStyle(Theme.accentOn)
                            .fontWeight(.bold)
                        Spacer()
                        Text(Format.clock(s.nowMs)).foregroundStyle(Theme.dim)
                    }
                    .font(.system(size: 12, weight: .bold).monospacedDigit())

                    Slider(
                        value: Binding(
                            get: { value },
                            set: { store.setSplitMinutes(Int($0.rounded())) }
                        ),
                        in: range,
                        step: 1
                    )
                    .disabled(s.whole || maxMins < 2)
                    .tint(Theme.accent)
                    .opacity(s.whole ? 0.35 : 1)

                    Text(subtitle(s: s, open: open))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
                .opacity(s.whole ? 0.45 : 1)

                Text(s.whole ? "THE WHOLE BLOCK BECOMES" : "REMAINDER BECOMES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.mute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.categories.filter { $0.key != open.key }) { cat in
                            Button {
                                store.doSplit(key: cat.key)
                            } label: {
                                HStack(spacing: 12) {
                                    Rectangle()
                                        .fill(Theme.hex(cat.hex))
                                        .frame(width: 12, height: 28)
                                    Text(cat.face.uppercased())
                                        .font(.system(size: 18, weight: .bold))
                                    Spacer()
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Rectangle().fill(Theme.rule2.opacity(0.5)).frame(height: 1)
                        }
                    }
                }
            }
            .foregroundStyle(Theme.fg)
            .background(Theme.ground.ignoresSafeArea())
        } else {
            Color.clear.onAppear { store.split = nil }
        }
    }

    private func subtitle(s: TapStore.SplitState, open: OpenBlock) -> String {
        if s.whole {
            return "next tap renames the whole block"
        }
        return "\(Format.duration(s.atMs - s.startMs)) stays \(store.labelFor(open.key).uppercased()) · \(Format.duration(s.nowMs - s.atMs)) becomes ↓"
    }

    private func scopeBtn(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(on ? Theme.panel2 : Theme.panel)
                .overlay(Rectangle().strokeBorder(on ? Theme.fg : Theme.rule2, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func sheetHeader(title: String, close: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.0)
            Spacer()
            Button("CLOSE", action: close)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.dim)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule2).frame(height: 2) }
    }
}
