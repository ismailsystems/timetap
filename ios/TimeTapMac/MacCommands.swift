import AppKit
import SwiftUI

/// App init should set `MacCommandHub.store = store`.
enum MacCommandHub {
    static weak var store: TapStore?
    static var openMain: (() -> Void)?

    @MainActor
    static func showMain() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow() {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
        } else {
            openMain?()
        }
    }

    @MainActor
    private static func mainWindow() -> NSWindow? {
        let candidates = NSApp.windows.filter { window in
            guard window.canBecomeMain, !(window is NSPanel) else { return false }
            let id = window.identifier?.rawValue ?? ""
            if id.localizedCaseInsensitiveContains("settings") { return false }
            if window.title == "Settings" { return false }
            return true
        }
        return candidates.first { ($0.identifier?.rawValue ?? "").hasPrefix("main") }
            ?? candidates.first
    }
}

struct MacCommands: Commands {
    @ObservedObject var store: TapStore

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About timetap") {
                NSApp.orderFrontStandardAboutPanel(options: [
                    .applicationName: "timetap",
                    .credits: NSAttributedString(string: "PLAN on the left. ACTUAL on the right.")
                ])
            }
        }
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .printItem) {}
        CommandGroup(replacing: .help) {}
        CommandMenu("Capture") {
            Button("Distracted") {
                store.toggleDistract()
                revealIfNeeded()
            }
                .keyboardShortcut("d")
                .disabled(store.open == nil)
            Button("Stop") {
                store.endDay()
                revealIfNeeded()
            }
                .disabled(store.open == nil)
                .accessibilityLabel("Stop the running block")
                .accessibilityHint("Does not stop sitting")
            Button(store.sit != nil ? "Stand" : "Sit") {
                store.toggleSit()
                revealIfNeeded()
            }
            Divider()
            ForEach(Array(leaves.prefix(9).enumerated()), id: \.offset) { i, child in
                Button(child.label) { propose(child.label) }
                    .keyboardShortcut(KeyEquivalent(Character(String(i + 1))))
            }
        }
        CommandGroup(after: .windowArrangement) {
            Button("Show TimeTap") { MacCommandHub.showMain() }
        }
    }

    private var leaves: [Category] {
        store.groups.flatMap(\.children)
    }

    private func propose(_ label: String) {
        if store.open?.key != label {
            store.propose(label)
        }
        revealIfNeeded()
    }

    private func revealIfNeeded() {
        if store.showSignIn || store.showPicker || store.markStrip != nil || store.showDead {
            MacCommandHub.showMain()
        }
    }
}
