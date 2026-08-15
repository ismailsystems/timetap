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
    private var sub: AnyCancellable?

    private func attach(_ store: TapStore) {
        self.store = store
        if item == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let menu = NSMenu()
            menu.autoenablesItems = false
            menu.delegate = self
            item.menu = menu
            self.item = item
        }
        sub = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    private func refresh() {
        guard let store else { return }
        item?.button?.title = store.open.map { store.labelFor($0.key) } ?? "TT"
        if let menu = item?.menu { rebuild(menu) }
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
            keyEquivalent: "s"
        )
        sit.target = self
        sit.state = store.sit != nil ? .on : .off
        menu.addItem(sit)

        let stop = NSMenuItem(title: "Stop", action: #selector(endDay), keyEquivalent: ".")
        stop.target = self
        menu.addItem(stop)

        menu.addItem(.separator())
        let show = NSMenuItem(title: "Show TimeTap", action: #selector(showWindow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
    }

    private func statusLine(_ store: TapStore) -> String {
        guard let open = store.open else { return "TT" }
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
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: \.canBecomeMain) {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            MacCommandHub.openMain?()
        }
    }
}
