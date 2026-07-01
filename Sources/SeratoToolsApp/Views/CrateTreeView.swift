import SwiftUI
import SeratoToolsCore

struct CrateTreeView: View {
    @ObservedObject var crateHierarchy: CrateHierarchyViewModel
    @ObservedObject var smartCrateHierarchy: CrateHierarchyViewModel
    @Binding var selectedNode: CrateNode?

    @State private var searchText = ""
    @State private var pendingDelete: (node: CrateNode, viewModel: CrateHierarchyViewModel)?
    @State private var deleteErrorMessage: String?

    var body: some View {
        List(selection: $selectedNode) {
            Section("Crates") {
                OutlineGroup(crateHierarchy.visibleTree, children: \.outlineChildren) { node in
                    row(for: node, in: crateHierarchy).tag(node)
                }
            }

            if !smartCrateHierarchy.visibleTree.isEmpty {
                Section("Smart Crates") {
                    OutlineGroup(smartCrateHierarchy.visibleTree, children: \.outlineChildren) { node in
                        row(for: node, in: smartCrateHierarchy).tag(node)
                    }
                }
            }

            let hidden = crateHierarchy.hiddenNodes + smartCrateHierarchy.hiddenNodes
            if !hidden.isEmpty {
                Section {
                    DisclosureGroup("Hidden (\(hidden.count))") {
                        ForEach(hidden) { node in
                            HStack {
                                Text(node.name)
                                Spacer()
                                Button("Unhide") { unhide(node) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Filter crates")
        .onChange(of: searchText) { _, newValue in
            crateHierarchy.searchText = newValue
            smartCrateHierarchy.searchText = newValue
        }
        .navigationTitle("Crates")
        .alert(
            "Delete Crate?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("Delete", role: .destructive) { confirmDelete() }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let pendingDelete {
                let count = pendingDelete.viewModel.deletionCount(for: pendingDelete.node)
                Text("This will move \(count) crate file\(count == 1 ? "" : "s") to the Trash.")
            }
        }
        .alert(
            "Couldn't Delete Crate",
            isPresented: Binding(get: { deleteErrorMessage != nil }, set: { if !$0 { deleteErrorMessage = nil } })
        ) {
            Button("OK") { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func row(for node: CrateNode, in viewModel: CrateHierarchyViewModel) -> some View {
        Text(node.name)
            .contextMenu {
                Button("Hide") { viewModel.hide(node) }
                if viewModel.allowsDelete {
                    Button("Delete…", role: .destructive) {
                        pendingDelete = (node, viewModel)
                    }
                }
            }
    }

    private func unhide(_ node: CrateNode) {
        if crateHierarchy.hiddenNodes.contains(node) {
            crateHierarchy.unhide(node)
        } else {
            smartCrateHierarchy.unhide(node)
        }
    }

    private func confirmDelete() {
        guard let pendingDelete else { return }
        do {
            try pendingDelete.viewModel.delete(pendingDelete.node)
            if selectedNode == pendingDelete.node {
                selectedNode = nil
            }
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
        self.pendingDelete = nil
    }
}

private extension CrateNode {
    var outlineChildren: [CrateNode]? { children.isEmpty ? nil : children }
}
