import SwiftUI

struct CategoryEditor: View {
    @EnvironmentObject private var store: TapStore
    @State private var newGroup = ""
    @State private var newChild: [String: String] = [:]
    @State private var renameTarget: Rename?
    @State private var deleteTarget: Delete?
    @State private var draft = ""

    private enum Rename: Identifiable {
        case pair(group: String, child: String)
        case group(String)
        case child(String)
        var id: String {
            switch self {
            case .pair(let g, let c): return "p:\(g):\(c)"
            case .group(let s): return "g:" + s
            case .child(let s): return "c:" + s
            }
        }
    }

    private enum Delete: Identifiable {
        case group(String)
        case child(String)
        var id: String {
            switch self {
            case .group(let s): return "g:" + s
            case .child(let s): return "c:" + s
            }
        }
    }

    var body: some View {
        List {
            ForEach(store.groups) { group in
                Section {
                    if group.children.count > 1 {
                        Button {
                            renameTarget = .group(group.label)
                            draft = group.label
                        } label: {
                            Text(group.label)
                                .font(Theme.rowFont(11, weight: .regular))
                                .tracking(0.4)
                                .foregroundStyle(Theme.dim)
                        }
                        .accessibilityLabel("Rename group \(group.label)")
                    }
                    ForEach(group.children) { child in
                        let one = group.children.count == 1
                        Button {
                            guard store.open?.key != child.label else { return }
                            if one {
                                renameTarget = .pair(group: group.label, child: child.label)
                            } else {
                                renameTarget = .child(child.label)
                            }
                            draft = child.label
                        } label: {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Theme.hex(child.hex))
                                    .frame(width: 8, height: one ? 18 : 28)
                                Text(child.label)
                                    .font(Theme.rowFont(20, weight: .semibold))
                                    .foregroundStyle(Theme.fg)
                                Spacer()
                            }
                        }
                        .disabled(store.open?.key == child.label)
                        .accessibilityLabel(one ? child.label : "\(group.label), \(child.label)")
                        .swipeActions {
                            if !one {
                                Button("Delete", role: .destructive) {
                                    deleteTarget = .child(child.label)
                                }
                            } else if store.groups.count > 1 {
                                Button("Delete", role: .destructive) {
                                    deleteTarget = .group(group.label)
                                }
                            }
                        }
                        .contextMenu {
                            if !one {
                                Button("Delete", role: .destructive) {
                                    deleteTarget = .child(child.label)
                                }
                            } else if store.groups.count > 1 {
                                Button("Delete", role: .destructive) {
                                    deleteTarget = .group(group.label)
                                }
                            }
                        }
                    }
                    HStack {
                        TextField("Add child", text: Binding(
                            get: { newChild[group.label] ?? "" },
                            set: { newChild[group.label] = $0 }
                        ))
                        .accessibilityLabel("Add child, \(group.label)")
                        Button("Add") {
                            store.addChild(group: group.label, label: newChild[group.label] ?? "")
                            newChild[group.label] = ""
                        }
                    }
                }
            }
            Section {
                TextField("New group", text: $newGroup)
                Button("Add group") {
                    store.addGroup(label: newGroup)
                    newGroup = ""
                }
                .disabled(!store.canAddCategory)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle("Categories")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Rename", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Name", text: $draft)
            Button("Save") { saveRename() }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .alert(deleteTitle, isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Delete", role: .destructive) { confirmDelete() }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text(deleteMessage)
        }
    }

    private var deleteTitle: String {
        switch deleteTarget {
        case .group(let name): return "Delete \(name)?"
        case .child(let name): return "Delete \(name)?"
        case .none: return "Delete?"
        }
    }

    private var deleteMessage: String {
        switch deleteTarget {
        case .group(let name):
            let kids = store.groups.first { $0.label == name }?.children.map(\.label) ?? []
            if kids.isEmpty { return "This group leaves." }
            return "\(kids.joined(separator: ", ")) leave with it."
        case .child(let name):
            return "\(name) leaves this group."
        case .none:
            return ""
        }
    }

    private func saveRename() {
        switch renameTarget {
        case .pair(let group, let child):
            store.renameChild(from: child, to: draft)
            store.renameGroup(from: group, to: draft)
        case .group(let from):
            store.renameGroup(from: from, to: draft)
        case .child(let from):
            store.renameChild(from: from, to: draft)
        case .none:
            break
        }
        renameTarget = nil
    }

    private func confirmDelete() {
        switch deleteTarget {
        case .group(let name): store.deleteGroup(name)
        case .child(let name): store.deleteChild(name)
        case .none: break
        }
        deleteTarget = nil
    }
}
