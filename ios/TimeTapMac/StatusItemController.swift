import AppKit
import Combine

/// TimeTapMacApp should call `StatusItemController.start(store:)` in init.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    static func start(store: TapStore) {
        shared.attach(store)
    }

    private static let shared = StatusItemController()
    private var store: TapStore?
    private var item: NSStatusItem?
    private let menu = NSMenu()
    private var sub: AnyCancellable?
    private var tick: Timer?

    private func attach(_ store: TapStore) {
        self.store = store
        if item == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            menu.autoenablesItems = false
            menu.delegate = self
            if let button = item.button {
                button.target = self
                button.action = #selector(statusClicked)
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.font = NSFont.monospacedDigitSystemFont(
                    ofSize: NSFont.smallSystemFontSize,
                    weight: .regular
                )
                if let image = NSImage(systemSymbolName: "clock", accessibilityDescription: "TimeTap") {
                    image.isTemplate = true
                    button.image = image
                    button.imagePosition = .imageLeading
                }
            }
            self.item = item
        }
        sub = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if tick == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            RunLoop.main.add(timer, forMode: .common)
            tick = timer
        }
        refresh()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    @objc private func statusClicked() {
        guard let event = NSApp.currentEvent else {
            MacCommandHub.showMain()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            MacCommandHub.showMain()
        }
    }

    private func showMenu() {
        guard let button = item?.button else { return }
        rebuild(menu)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func refresh() {
        guard let store else { return }
        item?.button?.title = barTitle(store)
        item?.button?.setAccessibilityLabel(
            store.open == nil ? "TimeTap, nothing running" : "TimeTap, \(barTitle(store))"
        )
    }

    private func barTitle(_ store: TapStore) -> String {
        guard let open = store.open else { return "TT" }
        let face = store.labelFor(open.key)
        let elapsed = Format.shortElapsed(store.clock() - open.startMs)
        return store.distracted ? "\(face) · \(elapsed) · off" : "\(face) · \(elapsed)"
    }

    private func rebuild(_ menu: NSMenu) {
        guard let store else { return }
        menu.removeAllItems()

        let status = NSMenuItem(title: statusLine(store), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        for cat in store.categories {
            let row = NSMenuItem(title: cat.label, action: #selector(propose(_:)), keyEquivalent: "")
            row.target = self
            row.representedObject = cat.label
            row.state = store.open?.key == cat.label ? .on : .off
            menu.addItem(row)
        }

        menu.addItem(.separator())

        let distract = NSMenuItem(title: "Distracted", action: #selector(toggleDistract), keyEquivalent: "d")
        distract.target = self
        distract.state = store.distracted ? .on : .off
        distract.isEnabled = store.open != nil
        menu.addItem(distract)

        let sit = NSMenuItem(
            title: store.sit != nil ? "Stand" : "Sit",
            action: #selector(toggleSit),
            keyEquivalent: ""
        )
        sit.target = self
        sit.state = store.sit != nil ? .on : .off
        menu.addItem(sit)

        let stop = NSMenuItem(title: "Stop", action: #selector(endDay), keyEquivalent: "")
        stop.target = self
        stop.isEnabled = store.open != nil
        menu.addItem(stop)

        menu.addItem(.separator())
        let show = NSMenuItem(title: "Show TimeTap", action: #selector(showWindow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        let quit = NSMenuItem(title: "Quit timetap", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func statusLine(_ store: TapStore) -> String {
        guard let open = store.open else { return "Nothing running" }
        let face = store.labelFor(open.key)
        return "\(face) \(Format.elapsed(store.clock() - open.startMs))"
    }

    @objc private func propose(_ sender: NSMenuItem) {
        guard let label = sender.representedObject as? String else { return }
        store?.propose(label)
    }

    @objc private func toggleDistract() {
        store?.toggleDistract()
    }

    @objc private func toggleSit() {
        store?.toggleSit()
    }

    @objc private func endDay() {
        store?.endDay()
    }

    @objc private func showWindow() {
        MacCommandHub.showMain()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
