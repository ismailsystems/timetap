import SwiftUI

/// App init should set `MacCommandHub.store = store`.
enum MacCommandHub {
    static weak var store: TapStore?
    static var openMain: (() -> Void)?
}

struct MacCommands: Commands {
    var body: some Commands {
        CommandMenu("Capture") {
            Button("Distracted") { MacCommandHub.store?.toggleDistract() }
                .keyboardShortcut("d")
            Button("Stop") { MacCommandHub.store?.endDay() }
                .keyboardShortcut(".")
            Button("Sit") { MacCommandHub.store?.toggleSit() }
                .keyboardShortcut("s")
            Divider()
            ForEach(1...9, id: \.self) { n in
                Button("Category \(n)") { proposeLeaf(n) }
                    .keyboardShortcut(KeyEquivalent(Character(String(n))))
            }
        }
    }

    private func proposeLeaf(_ n: Int) {
        let leaves = MacCommandHub.store?.groups.flatMap(\.children) ?? []
        guard leaves.indices.contains(n - 1) else { return }
        let label = leaves[n - 1].label
        if MacCommandHub.store?.open?.key != label {
            MacCommandHub.store?.propose(label)
        }
    }
}
