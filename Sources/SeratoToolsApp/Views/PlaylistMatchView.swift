import SwiftUI
import AppKit
import SeratoToolsCore

struct PlaylistMatchView: View {
    private enum BulkVersionPreference: String, CaseIterable, Identifiable {
        case auto
        case djOrder
        case intro
        case extended
        case instrumental
        case acapella
        case clean
        case dirty
        case radio
        case edit
        case mix

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .auto:
                return "Keep Current"
            case .djOrder:
                return "Prefer DJ Version Order"
            case .intro:
                return "Prefer Intro"
            case .extended:
                return "Prefer Extended"
            case .instrumental:
                return "Prefer Instrumental"
            case .acapella:
                return "Prefer Acapella"
            case .clean:
                return "Prefer Clean"
            case .dirty:
                return "Prefer Dirty"
            case .radio:
                return "Prefer Radio"
            case .edit:
                return "Prefer Edit"
            case .mix:
                return "Prefer Mix"
            }
        }
    }

    @EnvironmentObject private var libraryService: LibraryService

    let onLibraryChanged: () -> Void

    @State private var rawInput = ""
    @State private var crateName = "PlaylistMatch"
    @State private var isRunning = false
    @State private var isCreatingCrate = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var matchedEntries: [PlaylistMatchService.MatchedEntry] = []
    @State private var selectedVersionByEntryID: [UUID: UUID] = [:]
    @State private var bulkVersionPreference: BulkVersionPreference = .auto
    @State private var matchedTracks: [Track] = []
    @State private var planItems: [PlaylistMatchService.PlanItem] = []
    @State private var resolvedEntryCount = 0
    @State private var youtubeURLByPlanID: [UUID: String] = [:]
    @State private var rippingPlanIDs: Set<UUID> = []
    @State private var planStatusByID: [UUID: String] = [:]
    @State private var searchingPlanIDs: Set<UUID> = []
    @State private var youtubeSuggestionsByPlanID: [UUID: [YouTubeAudioImportService.SearchResult]] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeaderCard(
                    title: "PlaylistMatch",
                    description: "Paste a Spotify playlist link, text list, or CSV. PlaylistMatch scans your Serato library, builds a crate from matches, and keeps unmatched tracks in a Plan.",
                    icon: "music.quarternote.3"
                )

                inputCard
                summaryCard
                planCard
            }
            .padding(16)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paste Playlist Input")
                .font(.title3.weight(.semibold))

            TextEditor(text: $rawInput)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .frame(minHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Text("Input examples: Spotify playlist URL, CSV with Title/Artist columns, or lines like 'Artist - Title'.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Crate name", text: $crateName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)

                Button(isRunning ? "Scanning..." : "Scan Playlist") {
                    runMatch()
                }
                .disabled(isRunning)

                Button("Clear") {
                    clearResults()
                }
                .disabled(isRunning)

                Spacer(minLength: 0)
            }

            if let successMessage {
                Text(successMessage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.55)))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Match Summary")
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                statTag(title: "Playlist Tracks", value: "\(resolvedEntryCount)")
                statTag(title: "Matched Songs", value: "\(matchedEntries.count)", accent: true)
                statTag(title: "Selected Tracks", value: "\(matchedTracks.count)")
                statTag(title: "Plan", value: "\(planItems.count)")
                Spacer(minLength: 0)
            }

            Button(isCreatingCrate ? "Creating Crate..." : "Create Crate From Matches") {
                createCrateFromMatches()
            }
            .disabled(isCreatingCrate || matchedTracks.isEmpty)

            HStack(spacing: 8) {
                Picker("Bulk Version", selection: $bulkVersionPreference) {
                    ForEach(BulkVersionPreference.allCases) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 240)

                Button("Apply To All") {
                    applyBulkVersionPreference()
                }
                .disabled(matchedEntries.isEmpty)

                Spacer(minLength: 0)
            }

            if !matchedEntries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(matchedEntries.prefix(20))) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            let artist = item.entry.artist.isEmpty ? "Unknown Artist" : item.entry.artist
                            Text("• \(artist) - \(item.entry.title)")
                                .font(.callout.weight(.semibold))
                                .lineLimit(1)

                            Text("Versions in library: \(item.versions.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker(
                                "Selected Version",
                                selection: selectedVersionBinding(for: item)
                            ) {
                                ForEach(item.versions, id: \.id) { version in
                                    Text(versionPickerTitle(for: version))
                                        .tag(version.id.uuidString)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 440, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(item.versions.prefix(6)), id: \.id) { version in
                                    HStack(spacing: 6) {
                                        Text(versionLabel(for: version))
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(Color.accentColor.opacity(0.14))
                                            )
                                        Text(version.title.isEmpty ? version.fileURL.lastPathComponent : version.title)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }

                                if item.versions.count > 6 {
                                    Text("+ \(item.versions.count - 6) more versions")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if matchedEntries.count > 20 {
                        Text("+ \(matchedEntries.count - 20) more matched songs")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.55)))
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Plan")
                .font(.title3.weight(.semibold))

            if planItems.isEmpty {
                Text("No gaps found. Your matched crate can be created as-is.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Tracks PlaylistMatch couldn't find in your library:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Use Search YouTube to find a source, paste the video link, then Rip + Add to bring it into this crate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(planItems) { item in
                    let artist = item.entry.artist.isEmpty ? "Unknown Artist" : item.entry.artist
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• \(artist) - \(item.entry.title)")
                            .font(.callout.weight(.semibold))

                        HStack(spacing: 8) {
                            TextField(
                                "Paste YouTube URL",
                                text: Binding(
                                    get: { youtubeURLByPlanID[item.id] ?? "" },
                                    set: { youtubeURLByPlanID[item.id] = $0 }
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            Button(searchingPlanIDs.contains(item.id) ? "Finding..." : "Find In-App") {
                                searchYouTubeSuggestions(for: item)
                            }
                            .disabled(searchingPlanIDs.contains(item.id))

                            Button("Search YouTube") {
                                openYouTubeSearch(for: item.entry)
                            }

                            Button(rippingPlanIDs.contains(item.id) ? "Ripping..." : "Rip + Add") {
                                ripPlanItemFromYouTube(item)
                            }
                            .disabled(rippingPlanIDs.contains(item.id))
                        }

                        if let suggestions = youtubeSuggestionsByPlanID[item.id], !suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Suggestions")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(Array(suggestions.prefix(5))) { suggestion in
                                    HStack(alignment: .top, spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.title)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Text(suggestion.channel)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer(minLength: 0)

                                        Button("Use Link") {
                                            youtubeURLByPlanID[item.id] = suggestion.webpageURL.absoluteString
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)

                                        Button(rippingPlanIDs.contains(item.id) ? "Ripping..." : "Use + Rip") {
                                            ripPlanItemFromYouTube(item, preferredURL: suggestion.webpageURL)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .disabled(rippingPlanIDs.contains(item.id))
                                    }
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                            )
                        }

                        if let status = planStatusByID[item.id] {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.55)))
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

    private func clearResults() {
        resolvedEntryCount = 0
        matchedEntries = []
        selectedVersionByEntryID = [:]
        matchedTracks = []
        planItems = []
        youtubeURLByPlanID = [:]
        rippingPlanIDs = []
        planStatusByID = [:]
        searchingPlanIDs = []
        youtubeSuggestionsByPlanID = [:]
        successMessage = nil
        errorMessage = nil
    }

    private func runMatch() {
        isRunning = true
        successMessage = nil
        errorMessage = nil

        let input = rawInput
        let libraryTracks = libraryService.tracks

        Task {
            do {
                let entries = try await PlaylistMatchService.resolveEntries(from: input)
                let result = PlaylistMatchService.match(entries: entries, libraryTracks: libraryTracks)
                resolvedEntryCount = entries.count
                matchedEntries = result.matchedEntries
                selectedVersionByEntryID = Dictionary(
                    uniqueKeysWithValues: result.matchedEntries.map { ($0.entry.id, $0.primaryTrack.id) }
                )
                matchedTracks = selectedMatchedTracks(from: result.matchedEntries)
                planItems = result.planItems
                youtubeURLByPlanID = Dictionary(uniqueKeysWithValues: result.planItems.map { ($0.id, "") })
                planStatusByID = [:]
                youtubeSuggestionsByPlanID = [:]
                successMessage = "Matched \(result.matchedEntries.count) songs. Added \(result.planItems.count) to Plan."
            } catch {
                errorMessage = error.localizedDescription
            }

            isRunning = false
        }
    }

    private func createCrateFromMatches() {
        guard !matchedTracks.isEmpty else { return }
        isCreatingCrate = true
        errorMessage = nil

        do {
            let crateURL = try PlaylistMatchService.createCrateFromMatches(
                crateName: crateName,
                matchedTracks: matchedTracks,
                subcratesDirectory: libraryService.subcratesDirectory
            )
            onLibraryChanged()
            successMessage = "Created crate \(crateURL.deletingPathExtension().lastPathComponent) with \(matchedTracks.count) tracks."
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreatingCrate = false
    }

    private func selectedVersionBinding(for item: PlaylistMatchService.MatchedEntry) -> Binding<String> {
        Binding(
            get: {
                let selectedID = selectedVersionByEntryID[item.entry.id] ?? item.primaryTrack.id
                return selectedID.uuidString
            },
            set: { newValue in
                guard let trackID = UUID(uuidString: newValue) else { return }
                selectedVersionByEntryID[item.entry.id] = trackID
                matchedTracks = selectedMatchedTracks(from: matchedEntries)
            }
        )
    }

    private func selectedMatchedTracks(from entries: [PlaylistMatchService.MatchedEntry]) -> [Track] {
        var output: [Track] = []
        var seen = Set<String>()

        for entry in entries {
            let selectedTrackID = selectedVersionByEntryID[entry.entry.id] ?? entry.primaryTrack.id
            let selectedTrack = entry.versions.first(where: { $0.id == selectedTrackID }) ?? entry.primaryTrack
            if seen.insert(selectedTrack.seratoStoredPath).inserted {
                output.append(selectedTrack)
            }
        }

        return output
    }

    private func versionPickerTitle(for track: Track) -> String {
        let artist = track.artist.isEmpty ? "Unknown Artist" : track.artist
        let title = track.title.isEmpty ? track.fileURL.lastPathComponent : track.title
        return "\(versionLabel(for: track)) • \(artist) - \(title)"
    }

    private func applyBulkVersionPreference() {
        guard !matchedEntries.isEmpty else { return }

        switch bulkVersionPreference {
        case .auto:
            for entry in matchedEntries {
                selectedVersionByEntryID[entry.entry.id] = entry.primaryTrack.id
            }
        case .djOrder:
            for entry in matchedEntries {
                if let preferred = preferredDJOrderVersion(in: entry.versions) {
                    selectedVersionByEntryID[entry.entry.id] = preferred.id
                } else {
                    selectedVersionByEntryID[entry.entry.id] = entry.primaryTrack.id
                }
            }
        default:
            for entry in matchedEntries {
                if let preferred = preferredVersion(in: entry.versions, preference: bulkVersionPreference) {
                    selectedVersionByEntryID[entry.entry.id] = preferred.id
                } else {
                    selectedVersionByEntryID[entry.entry.id] = entry.primaryTrack.id
                }
            }
        }

        matchedTracks = selectedMatchedTracks(from: matchedEntries)
        successMessage = "Applied \(bulkVersionPreference.displayName) across matched songs."
    }

    private func preferredDJOrderVersion(in versions: [Track]) -> Track? {
        // Priority order: Intro > Extended > Clean > Dirty > Radio > Original/default.
        if let intro = versions.first(where: { matches($0, preference: .intro) }) {
            return intro
        }
        if let extended = versions.first(where: { matches($0, preference: .extended) }) {
            return extended
        }
        if let clean = versions.first(where: { matches($0, preference: .clean) }) {
            return clean
        }
        if let dirty = versions.first(where: { matches($0, preference: .dirty) }) {
            return dirty
        }
        if let radio = versions.first(where: { matches($0, preference: .radio) }) {
            return radio
        }
        return versions.first
    }

    private func preferredVersion(in versions: [Track], preference: BulkVersionPreference) -> Track? {
        versions.first(where: { matches($0, preference: preference) })
    }

    private func matches(_ track: Track, preference: BulkVersionPreference) -> Bool {
        let title = track.title.lowercased()

        switch preference {
        case .auto:
            return false
        case .djOrder:
            return false
        case .intro:
            return title.contains("intro")
        case .extended:
            return title.contains("extended")
        case .instrumental:
            return title.contains("instrumental")
        case .acapella:
            return title.contains("acapella") || title.contains("a cappella")
        case .clean:
            return title.contains("clean")
        case .dirty:
            return title.contains("dirty")
        case .radio:
            return title.contains("radio")
        case .edit:
            return title.contains("edit")
        case .mix:
            return title.contains("mix")
        }
    }

    private func openYouTubeSearch(for entry: PlaylistMatchService.PlaylistEntry) {
        let query = [entry.artist, entry.title]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !query.isEmpty else { return }
        guard var components = URLComponents(string: "https://www.youtube.com/results") else { return }
        components.queryItems = [URLQueryItem(name: "search_query", value: query)]
        guard let searchURL = components.url else { return }
        NSWorkspace.shared.open(searchURL)
    }

    private func searchYouTubeSuggestions(for item: PlaylistMatchService.PlanItem) {
        let query = [item.entry.artist, item.entry.title]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !query.isEmpty else {
            planStatusByID[item.id] = "Missing title/artist for search query."
            return
        }

        searchingPlanIDs.insert(item.id)
        planStatusByID[item.id] = "Searching YouTube..."

        Task {
            do {
                let suggestions = try await Task.detached(priority: .userInitiated) {
                    try YouTubeAudioImportService.searchVideos(query: query, maxResults: 5)
                }.value

                youtubeSuggestionsByPlanID[item.id] = suggestions
                if suggestions.isEmpty {
                    planStatusByID[item.id] = "No suggestions found."
                } else {
                    planStatusByID[item.id] = "Found \(suggestions.count) suggestions."
                }
            } catch {
                planStatusByID[item.id] = "Search failed: \(error.localizedDescription)"
            }

            searchingPlanIDs.remove(item.id)
        }
    }

    private func ripPlanItemFromYouTube(_ item: PlaylistMatchService.PlanItem, preferredURL: URL? = nil) {
        let selectedURL: URL?
        if let preferredURL {
            selectedURL = preferredURL
            youtubeURLByPlanID[item.id] = preferredURL.absoluteString
        } else {
            let rawURL = youtubeURLByPlanID[item.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            selectedURL = YouTubeBatchLinkImportService.parseVideoURLs(from: rawURL).first
        }

        guard let videoURL = selectedURL else {
            errorMessage = PlaylistMatchRipError.invalidYouTubeURL.localizedDescription
            return
        }

        let dependencyStatus = YouTubeAudioImportService.dependencyStatus()
        guard dependencyStatus.isReady else {
            errorMessage = PlaylistMatchRipError.dependenciesMissing.localizedDescription
            return
        }

        errorMessage = nil
        successMessage = nil
        rippingPlanIDs.insert(item.id)
        planStatusByID[item.id] = "Downloading from YouTube..."

        let destinationFolderURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music", isDirectory: true)

        let metadata = SeratoTrackMetadataUpdate(
            title: item.entry.title,
            artist: item.entry.artist,
            album: "",
            genre: "",
            comment: videoURL.absoluteString,
            key: "",
            bpm: nil,
            year: nil
        )

        Task {
            do {
                let crate = try resolveOrCreateTargetCrate()
                let rootDirectory = libraryService.rootDirectory

                let outputFileURL = try await Task.detached(priority: .userInitiated) {
                    let download = try YouTubeAudioImportService.downloadAudio(
                        .init(
                            videoURL: videoURL,
                            destinationFolderURL: destinationFolderURL,
                            audioFormat: .mp3,
                            audioQuality: .high,
                            audioBitrateKbps: 320,
                            metadata: metadata
                        )
                    )

                    _ = try AddMusicImportService.appendAudioFiles(
                        [download.outputFileURL],
                        toExistingCrate: crate,
                        rootDirectory: rootDirectory
                    )

                    return download.outputFileURL
                }.value

                onLibraryChanged()
                planItems.removeAll { $0.id == item.id }
                youtubeURLByPlanID[item.id] = ""
                planStatusByID[item.id] = "Downloaded \(outputFileURL.lastPathComponent) and added to crate."
                successMessage = "Downloaded \(outputFileURL.lastPathComponent) and added it to \(targetCrateName)."
            } catch {
                errorMessage = error.localizedDescription
                planStatusByID[item.id] = "Failed: \(error.localizedDescription)"
            }

            rippingPlanIDs.remove(item.id)
        }
    }

    private var targetCrateName: String {
        let trimmed = crateName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "PlaylistMatch" : trimmed
        return fallback
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
    }

    private func versionLabel(for track: Track) -> String {
        let title = track.title.lowercased()
        if title.contains("extended") {
            return "Extended"
        }
        if title.contains("intro") {
            return "Intro"
        }
        if title.contains("instrumental") {
            return "Instrumental"
        }
        if title.contains("acapella") || title.contains("a cappella") {
            return "Acapella"
        }
        if title.contains("clean") {
            return "Clean"
        }
        if title.contains("dirty") {
            return "Dirty"
        }
        if title.contains("radio") {
            return "Radio"
        }
        if title.contains("edit") {
            return "Edit"
        }
        if title.contains("mix") {
            return "Mix"
        }
        return "Version"
    }

    private func resolveOrCreateTargetCrate() throws -> Crate {
        if let existing = libraryService.crates.first(where: { $0.name == targetCrateName }) {
            return existing
        }

        guard !matchedTracks.isEmpty else {
            throw PlaylistMatchRipError.targetCrateMissing
        }

        _ = try PlaylistMatchService.createCrateFromMatches(
            crateName: targetCrateName,
            matchedTracks: selectedMatchedTracks(from: matchedEntries),
            subcratesDirectory: libraryService.subcratesDirectory
        )
        onLibraryChanged()

        if let created = libraryService.crates.first(where: { $0.name == targetCrateName }) {
            return created
        }

        throw PlaylistMatchRipError.targetCrateMissing
    }
}

private enum PlaylistMatchRipError: LocalizedError {
    case dependenciesMissing
    case invalidYouTubeURL
    case targetCrateMissing

    var errorDescription: String? {
        switch self {
        case .dependenciesMissing:
            return "yt-dlp and ffmpeg are required before ripping from YouTube."
        case .invalidYouTubeURL:
            return "Paste a valid YouTube URL for this Plan item first."
        case .targetCrateMissing:
            return "Create your PlaylistMatch crate from matched tracks before adding ripped Plan items."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .dependenciesMissing:
            return "Install yt-dlp and ffmpeg, then try Rip + Add again."
        case .invalidYouTubeURL:
            return "Use a full youtube.com or youtu.be link."
        case .targetCrateMissing:
            return "Click Create Crate From Matches, then retry the Plan item rip."
        }
    }
}