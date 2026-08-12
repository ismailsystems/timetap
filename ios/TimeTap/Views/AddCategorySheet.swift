import SwiftUI

struct AddCategorySheet: View {
    @EnvironmentObject private var store: TapStore
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("name it — this is the only chance", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(commit)
                } footer: {
                    Text(
                        "Adds a category on the server (up to \(store.config?.maxCategories ?? 10)). " +
                        "There is no rename later."
                    )
                }
            }
            .navigationTitle("Add category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { store.showAddCategory = false }
                        .disabled(store.addingCategory)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if store.addingCategory {
                        ProgressView()
                    } else {
                        Button("Add", action: commit)
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onAppear { focused = true }
            .interactiveDismissDisabled(store.addingCategory)
        }
        .preferredColorScheme(.dark)
    }

    private func commit() {
        store.addCategory(label: name)
    }
}
