import SwiftUI
import SeratoToolsCore

enum SidebarSection: Hashable {
    case tracks
    case crates
    case missingTracks
}

struct ContentView: View {
    @EnvironmentObject private var libraryService: LibraryService
    @ObservedObject var crateHierarchy: CrateHierarchyViewModel
    @ObservedObject var smartCrateHierarchy: CrateHierarchyViewModel

    @State private var selectedSection: SidebarSection? = .tracks
    @State private var selectedCrateNode: CrateNode?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Label("Tracks", systemImage: "music.note.list").tag(SidebarSection.tracks)
                Label("Crates", systemImage: "square.stack").tag(SidebarSection.crates)
                Label("Missing Tracks", systemImage: "exclamationmark.triangle").tag(SidebarSection.missingTracks)
            }
            .navigationTitle("SeratoTools")
        } content: {
            switch selectedSection {
            case .tracks:
                TrackTableView(tracks: libraryService.tracks)
                    .navigationTitle("Tracks")
            case .crates:
                CrateTreeView(
                    crateHierarchy: crateHierarchy,
                    smartCrateHierarchy: smartCrateHierarchy,
                    selectedNode: $selectedCrateNode
                )
            case .missingTracks:
                MissingTracksView()
            case nil:
                Text("Select a section")
                    .foregroundStyle(.secondary)
            }
        } detail: {
            if selectedSection == .crates, let node = selectedCrateNode {
                CrateDetailView(node: node)
            } else {
                Text("Select an item")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            try? libraryService.reload()
            crateHierarchy.rebuild(from: libraryService.crates)
            smartCrateHierarchy.rebuild(from: libraryService.smartCrates)
        }
    }
}
