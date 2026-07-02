import SwiftUI
import SeratoToolsCore

struct TrackMetadataEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let track: Track
    let onSave: (SeratoTrackMetadataUpdate) -> Void

    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var genre: String
    @State private var comment: String
    @State private var key: String
    @State private var bpmText: String
    @State private var yearText: String

    init(track: Track, onSave: @escaping (SeratoTrackMetadataUpdate) -> Void) {
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
                    onSave(
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
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 520)
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
}
