import SwiftUI
import SeratoToolsCore

struct DuplicateTracksView: View {
    @EnvironmentObject private var libraryService: LibraryService

    @State private var searchText = ""
    @State private var duplicateGroups: [DuplicateTrackGroup] = []
    @State private var summary = DuplicateTracksSummary(totalTracks: 0, duplicateGroupCount: 0, redundantTrackCount: 0, versionSeparatedGroupCount: 0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeaderCard(
                    title: "Duplicates",
                    description: "Find duplicate tracks by title and artist while keeping DJ version variants like Intro, Clean, Quick Hit, and Extended in separate groups.",
                    icon: "rectangle.on.rectangle"
                )

                summaryCard
                searchCard
                resultsCard
            }
            .padding(16)
        }
        .onAppear {
            rebuildDuplicateGroups()
        }
        .onChange(of: libraryService.tracks.count) {
            rebuildDuplicateGroups()
        }
        .onChange(of: libraryService.tracks.first?.id) {
            rebuildDuplicateGroups()
        }
        .onChange(of: libraryService.tracks.last?.id) {
            rebuildDuplicateGroups()
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Duplicate Summary")
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                statTag(title: "Tracks", value: "\(summary.totalTracks)")
                statTag(title: "Groups", value: "\(summary.duplicateGroupCount)", accent: true)
                statTag(title: "Redundant", value: "\(summary.redundantTrackCount)")
                statTag(title: "Versioned", value: "\(summary.versionSeparatedGroupCount)")
                statTag(title: "Diff Names", value: "\(differentFilenameGroupCount)")
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.55)))
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search title, artist, version, or path", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if duplicateGroups.isEmpty {
                Text(libraryService.tracks.isEmpty ? "Load a library first to scan for duplicates." : "No duplicate groups found.")
                    .foregroundStyle(.secondary)
            } else {
                Text("\(filteredGroups.count) groups match the current search.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.55)))
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Duplicate Groups")
                .font(.title3.weight(.semibold))

            if filteredGroups.isEmpty {
                Text(duplicateGroups.isEmpty ? "No duplicate groups detected in the current library." : "No duplicate groups matched your search.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(filteredGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(group.artist) - \(group.title)")
                                        .font(.headline)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text("Version: \(group.versionLabel)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(group.hasDifferentFilenames ? "Different filenames" : "Same filename")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill((group.hasDifferentFilenames ? Color.orange : Color.green).opacity(0.16))
                                            )
                                            .foregroundStyle(group.hasDifferentFilenames ? Color.orange : Color.green)
                                    }
                                }

                                Spacer(minLength: 0)

                                statTag(title: "Tracks", value: "\(group.trackCount)", accent: true)
                                statTag(title: "Redundant", value: "\(group.redundantTrackCount)")
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(group.tracks) { track in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(track.title.isEmpty ? track.fileURL.deletingPathExtension().lastPathComponent : track.title)
                                                .font(.subheadline)
                                            Text(DuplicateTracksService.versionLabel(for: track))
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                            Spacer(minLength: 0)
                                        }
                                        Text(track.artist.isEmpty ? track.fileURL.lastPathComponent : track.artist)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("File: \(track.fileURL.lastPathComponent)")
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        Text(track.fileURL.path)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.55))
                                    )
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.66))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.55)))
    }

    private var filteredGroups: [DuplicateTrackGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return duplicateGroups }

        return duplicateGroups.filter { group in
            if group.artist.lowercased().contains(query) { return true }
            if group.title.lowercased().contains(query) { return true }
            if group.versionLabel.lowercased().contains(query) { return true }
            return group.tracks.contains { track in
                track.title.lowercased().contains(query)
                    || track.artist.lowercased().contains(query)
                    || track.fileURL.path.lowercased().contains(query)
            }
        }
    }

    private var differentFilenameGroupCount: Int {
        duplicateGroups.filter { $0.hasDifferentFilenames }.count
    }

    private func rebuildDuplicateGroups() {
        duplicateGroups = DuplicateTracksService.duplicateGroups(in: libraryService.tracks)
        summary = DuplicateTracksService.summary(for: libraryService.tracks)
    }

    private func statTag(title: String, value: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(accent ? .white.opacity(0.92) : .secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .default))
                .monospacedDigit()
                .foregroundStyle(accent ? .white : .primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(accent ? Color.accentColor.opacity(0.92) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}