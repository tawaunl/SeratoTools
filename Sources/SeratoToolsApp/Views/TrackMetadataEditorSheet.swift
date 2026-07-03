import SwiftUI
import SeratoToolsCore

struct TrackMetadataEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let track: Track
    let onSave: (SeratoTrackMetadataUpdate) throws -> Void

    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var genre: String
    @State private var comment: String
    @State private var key: String
    @State private var bpmText: String
    @State private var yearText: String
    @State private var sourceSelection: OnlineTrackMetadataLookupService.SourceSelection = .all
    @State private var lookupResults: [OnlineTrackMetadataCandidate] = []
    @State private var isSearchingOnline = false
    @State private var lookupErrorMessage: String?
    @State private var saveErrorMessage: String?

    init(track: Track, onSave: @escaping (SeratoTrackMetadataUpdate) throws -> Void) {
        self.track = track
        self.onSave = onSave
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
        _album = State(initialValue: track.album)
        _genre = State(initialValue: track.genre)
        _comment = State(initialValue: track.comment)
        _key = State(initialValue: track.key ?? "")
        _bpmText = State(initialValue: track.bpm.map { String(format: "%.0f", $0) } ?? "")
        _yearText = State(initialValue: track.year.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Track")
                .font(.headline)
            Text(track.fileURL.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Picker("Source", selection: $sourceSelection) {
                    ForEach(OnlineTrackMetadataLookupService.SourceSelection.allCases, id: \.self) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                .pickerStyle(.menu)

                Button("Search Online") {
                    searchOnline()
                }
                .disabled(isSearchingOnline)

                if isSearchingOnline {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }

            if let lookupErrorMessage {
                Text(lookupErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let saveErrorMessage {
                Text(saveErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !lookupResults.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Online Matches")
                        .font(.subheadline.weight(.semibold))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(lookupResults.prefix(10)) { candidate in
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(candidate.source.displayName): \(candidate.title.isEmpty ? "(untitled)" : candidate.title)")
                                            .font(.callout)

                                        Text(summary(for: candidate))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer(minLength: 0)

                                    Button("Use All") {
                                        apply(candidate: candidate)
                                    }
                                }

                                FlowLayout(spacing: 6) {
                                    if !candidate.title.isEmpty {
                                        fieldButton("Title") { title = candidate.title }
                                    }
                                    if !candidate.artist.isEmpty {
                                        fieldButton("Artist") { artist = candidate.artist }
                                    }
                                    if !candidate.album.isEmpty {
                                        fieldButton("Album") { album = candidate.album }
                                    }
                                    if !candidate.genre.isEmpty {
                                        fieldButton("Genre") { genre = candidate.genre }
                                    }
                                    if let year = candidate.year {
                                        fieldButton("Year") { yearText = String(year) }
                                    }
                                    if let bpm = candidate.bpm {
                                        fieldButton("BPM") { bpmText = String(format: "%.0f", bpm) }
                                    }
                                    if !candidate.comment.isEmpty {
                                        fieldButton("Comment") { comment = candidate.comment }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 170)
                }
            }

            Group {
                row("Title", text: $title)
                row("Artist", text: $artist)
                row("Album", text: $album)
                row("Genre", text: $genre)
                row("Key", text: $key)
                row("BPM", text: $bpmText)
                row("Year", text: $yearText)
                row("Comment", text: $comment)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    do {
                        try onSave(
                            SeratoTrackMetadataUpdate(
                                title: title,
                                artist: artist,
                                album: album,
                                genre: genre,
                                comment: comment,
                                key: key,
                                bpm: Double(bpmText.trimmingCharacters(in: .whitespacesAndNewlines)),
                                year: Int(yearText.trimmingCharacters(in: .whitespacesAndNewlines))
                            )
                        )
                        dismiss()
                    } catch {
                        saveErrorMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 560)
    }

    private func row(_ label: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func fieldButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    private func searchOnline() {
        lookupErrorMessage = nil
        isSearchingOnline = true

        Task {
            do {
                let results = try await OnlineTrackMetadataLookupService.lookup(
                    query: .init(title: title, artist: artist, album: album),
                    sourceSelection: sourceSelection
                )

                await MainActor.run {
                    lookupResults = results
                    if results.isEmpty {
                        lookupErrorMessage = "No matches found from the selected source(s)."
                    }
                    isSearchingOnline = false
                }
            } catch {
                await MainActor.run {
                    lookupResults = []
                    lookupErrorMessage = error.localizedDescription
                    isSearchingOnline = false
                }
            }
        }
    }

    private func apply(candidate: OnlineTrackMetadataCandidate) {
        if !candidate.title.isEmpty {
            title = candidate.title
        }
        if !candidate.artist.isEmpty {
            artist = candidate.artist
        }
        if !candidate.album.isEmpty {
            album = candidate.album
        }
        if !candidate.genre.isEmpty {
            genre = candidate.genre
        }
        if let year = candidate.year {
            yearText = String(year)
        }
        if let bpm = candidate.bpm {
            bpmText = String(format: "%.0f", bpm)
        }
        if !candidate.comment.isEmpty {
            comment = candidate.comment
        }
    }

    private func summary(for candidate: OnlineTrackMetadataCandidate) -> String {
        [
            candidate.artist,
            candidate.album,
            candidate.genre,
            candidate.year.map(String.init) ?? ""
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0 && currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            usedWidth = max(usedWidth, currentX + size.width)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: usedWidth, height: currentY + lineHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
