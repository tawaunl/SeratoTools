import SwiftUI
import SeratoToolsCore

struct CrateDetailView: View {
    let node: CrateNode
    @EnvironmentObject private var libraryService: LibraryService

    var body: some View {
        Group {
            if let crate = node.crate {
                let tracksByPath = Dictionary(
                    libraryService.tracks.map { ($0.seratoStoredPath, $0) },
                    uniquingKeysWith: { first, _ in first }
                )
                let matchedTracks = crate.trackPaths.compactMap { tracksByPath[$0] }
                let unmatchedPaths = crate.trackPaths.filter { tracksByPath[$0] == nil }

                VStack(alignment: .leading, spacing: 0) {
                    TrackTableView(tracks: matchedTracks)

                    // Confirmed to happen legitimately for some Smart Crate
                    // entries referencing a different Serato profile/volume
                    // context — shown separately rather than as an error.
                    if !unmatchedPaths.isEmpty {
                        Divider()
                        DisclosureGroup("Not in local library (\(unmatchedPaths.count))") {
                            ForEach(unmatchedPaths, id: \.self) { path in
                                Text(path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Tracks",
                    systemImage: "folder",
                    description: Text("This groups nested crates — select one of its children to see tracks.")
                )
            }
        }
        .navigationTitle(node.name)
    }
}
