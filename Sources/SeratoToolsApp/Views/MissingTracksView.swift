import SwiftUI
import SeratoToolsCore

struct MissingTracksView: View {
    @EnvironmentObject private var libraryService: LibraryService
    @EnvironmentObject private var missingTracksService: MissingTracksService

    @State private var resultMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderCard(
                title: "Missing Tracks",
                description: "Scan for moved or renamed files, then repair the missing entries or gather them into a review crate.",
                icon: "exclamationmark.triangle"
            )

            HStack {
                Text("\(missingTracksService.candidates.count) missing tracks")
                    .font(.headline)
                Spacer()
                if missingTracksService.isScanning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }
                Button("Scan for Matches") {
                    Task { await missingTracksService.scanForMatches() }
                }
                .disabled(missingTracksService.candidates.isEmpty || missingTracksService.isScanning)
                Button("Gather into Review Crate") {
                    gatherIntoCrate()
                }
                .disabled(missingTracksService.candidates.isEmpty)
            }
            .padding()

            List(missingTracksService.candidates) { candidate in
                MissingTrackRow(candidate: candidate)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle("Missing Tracks")
        .task {
            missingTracksService.detectMissingTracks(in: libraryService.tracks)
        }
        .alert(
            "Missing Tracks",
            isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })
        ) {
            Button("OK") { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
        .padding(.horizontal, 8)
    }

    private func gatherIntoCrate() {
        do {
            let url = try missingTracksService.gatherIntoReviewCrate(subcratesDirectory: libraryService.subcratesDirectory)
            resultMessage = "Created \(url.lastPathComponent). Reload the library in Serato to see it."
            try? libraryService.reload()
        } catch {
            resultMessage = "Couldn't create the review crate: \(error.localizedDescription)"
        }
    }
}

private struct MissingTrackRow: View {
    @EnvironmentObject private var missingTracksService: MissingTracksService
    let candidate: MissingTrackCandidate

    @State private var errorMessage: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(candidate.track.title.isEmpty ? candidate.track.fileURL.lastPathComponent : candidate.track.title)
                Text(candidate.track.seratoStoredPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            actionControl
        }
        .alert(
            "Couldn't Fix Track",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // Even a single unambiguous match requires an explicit click — a
    // same-filename match is a weaker signal than it looks (e.g. generic
    // filenames), so nothing here is ever auto-applied.
    @ViewBuilder
    private var actionControl: some View {
        switch candidate.matches.count {
        case 0:
            Text("No match found")
                .font(.caption)
                .foregroundStyle(.secondary)
        case 1:
            Button("Fix") { fix(using: candidate.matches[0]) }
        default:
            Menu("Fix (\(candidate.matches.count) matches)") {
                ForEach(candidate.matches, id: \.self) { match in
                    Button(match.path) { fix(using: match) }
                }
            }
        }
    }

    private func fix(using url: URL) {
        do {
            try missingTracksService.repair(candidate, using: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
