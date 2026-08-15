import AppKit
import SwiftUI

/// App init should set `MacCommandHub.store = store`.
enum MacCommandHub {
    static weak var store: TapStore?
    static var openMain: (() -> Void)?
}

struct MacCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About timetap") {
                NSApp.orderFrontStandardAboutPanel(options: [
                    .applicationName: "timetap",
                    .credits: NSAttributedString(string: "PLAN on the left. ACTUAL on the right.")
                ])
            }
        }
        CommandMenu("Capture") {
            Button("Distracted") { MacCommandHub.store?.toggleDistract() }
                .keyboardShortcut("d")
                .disabled(MacCommandHub.store?.open == nil)
            Button("Stop") { MacCommandHub.store?.endDay() }
                .keyboardShortcut(".")
                .disabled(MacCommandHub.store?.open == nil)
                .accessibilityLabel("Stop the running block")
                .accessibilityHint("Does not stop sitting")
            Button(MacCommandHub.store?.sit != nil ? "Stand" : "Sit") {
                MacCommandHub.store?.toggleSit()
            }
            .keyboardShortcut("s")
            Divider()
            ForEach(Array(leaves.prefix(9).enumerated()), id: \.offset) { i, child in
                Button(child.label) { propose(child.label) }
                    .keyboardShortcut(KeyEquivalent(Character(String(i + 1))))
            }
        }
        CommandGroup(after: .windowArrangement) {
            Button("Show TimeTap") { MacCommandHub.openMain?() }
        }
    }

    private var leaves: [Category] {
        MacCommandHub.store?.groups.flatMap(\.children) ?? []
    }

    private func propose(_ label: String) {
        if MacCommandHub.store?.open?.key != label {
            MacCommandHub.store?.propose(label)
        }
    }
}
