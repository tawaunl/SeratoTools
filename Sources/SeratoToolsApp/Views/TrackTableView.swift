import SwiftUI
import SeratoToolsCore

/// A sortable, searchable library-style table of tracks — shared by the
/// top-level Tracks section and crate detail views, so both look and
/// behave consistently.
struct TrackTableView: View {
    let tracks: [Track]

    @State private var sortOrder: [KeyPathComparator<Track>] = [KeyPathComparator(\.title)]
    @State private var searchText = ""

    var body: some View {
        Table(filteredAndSorted, sortOrder: $sortOrder) {
            TableColumn("Title", value: \.title)
            TableColumn("Artist", value: \.artist)
            TableColumn("Album", value: \.album)
            TableColumn("Genre", value: \.genre)
            TableColumn("Key") { track in Text(track.key ?? "—") }
            TableColumn("BPM") { track in Text(Self.formattedBPM(track.bpm)) }
            TableColumn("Duration") { track in Text(Self.formattedDuration(track.duration)) }
        }
        .searchable(text: $searchText, prompt: "Search title, artist, genre…")
    }

    private var filteredAndSorted: [Track] {
        let base = searchText.isEmpty ? tracks : tracks.filter { track in
            track.title.localizedCaseInsensitiveContains(searchText)
                || track.artist.localizedCaseInsensitiveContains(searchText)
                || track.genre.localizedCaseInsensitiveContains(searchText)
                || track.album.localizedCaseInsensitiveContains(searchText)
        }
        return base.sorted(using: sortOrder)
    }

    private static func formattedBPM(_ bpm: Double?) -> String {
        guard let bpm else { return "—" }
        return String(format: "%.0f", bpm)
    }

    private static func formattedDuration(_ duration: TimeInterval?) -> String {
        guard let duration, duration > 0 else { return "—" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
