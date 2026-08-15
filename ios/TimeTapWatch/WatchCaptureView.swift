import SwiftUI

struct WatchCaptureView: View {
    @EnvironmentObject private var session: WatchSession

    private var running: Bool { session.state.openKey != nil }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    ChangeList()
                } label: {
                    Text("Change")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                Button {
                    session.send(.toggleDistract)
                } label: {
                    HStack {
                        Text("Distracted")
                        if session.state.distracted {
                            Spacer(minLength: 8)
                            Text(minutes(session.state.distractedMs))
                                .monospacedDigit()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .listRowBackground(session.state.distracted ? Color.orange : nil)
                .disabled(!running)
                if running {
                    Button("Stop") {
                        session.send(.endDay)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
            .safeAreaInset(edge: .top) { status }
        }
    }

    @ViewBuilder
    private var status: some View {
        if let key = session.state.openKey {
            VStack(spacing: 2) {
                Text(session.state.openFace ?? key)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                if let startMs = session.state.startMs {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(elapsed(from: startMs, now: context.date))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.top, 2)
        } else {
            Text("Nothing running")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
    }

    private func elapsed(from startMs: Double, now: Date) -> String {
        let sec = max(0, Int(now.timeIntervalSince1970 - startMs / 1000))
        let h = sec / 3600
        let m = (sec % 3600) / 60
        let s = sec % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func minutes(_ ms: Double) -> String {
        "\(Int(max(0, ms) / 60_000))m"
    }
}

private struct ChangeList: View {
    @EnvironmentObject private var session: WatchSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(session.state.groups) { group in
                if group.children.count == 1, let child = group.children.first {
                    childRow(child)
                } else if group.children.count > 1 {
                    Section(group.label) {
                        ForEach(group.children) { childRow($0) }
                    }
                }
            }
        }
    }

    private func childRow(_ child: WatchChild) -> some View {
        Button(child.label) {
            session.send(.propose(key: child.label))
            dismiss()
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}
