// EZLibrary — an open source toolkit for Serato DJ libraries.
// Copyright (C) 2026 Tawaun Lucas
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import Foundation
@testable import EZLibraryCore

private func makeTrack(
    title: String = "",
    artist: String = "",
    album: String = "",
    genre: String = "",
    path: String = "Music/song.mp3"
) -> Track {
    Track(
        seratoStoredPath: path,
        fileURL: URL(fileURLWithPath: "/Volumes/Library/\(path)"),
        title: title,
        artist: artist,
        album: album,
        genre: genre
    )
}

@Test func trackSearchEmptyQueryReturnsAll() {
    let tracks = [makeTrack(title: "One"), makeTrack(title: "Two")]
    #expect(TrackTextSearch.filter(tracks, query: "").count == 2)
    #expect(TrackTextSearch.filter(tracks, query: "   ").count == 2)
}

@Test func trackSearchIsCaseInsensitiveAcrossFields() {
    let tracks = [
        makeTrack(title: "Feel So Close", artist: "Calvin Harris"),
        makeTrack(title: "Titanium", artist: "David Guetta"),
        makeTrack(title: "Wake Me Up", artist: "Avicii", genre: "House"),
        makeTrack(title: "Levels", album: "Levels Single")
    ]

    #expect(TrackTextSearch.filter(tracks, query: "calvin").map(\.title) == ["Feel So Close"])
    #expect(TrackTextSearch.filter(tracks, query: "GUETTA").map(\.title) == ["Titanium"])
    #expect(TrackTextSearch.filter(tracks, query: "house").map(\.title) == ["Wake Me Up"])
    #expect(TrackTextSearch.filter(tracks, query: "levels").map(\.title) == ["Levels"])
}

@Test func trackSearchMatchesSubstring() {
    let tracks = [makeTrack(title: "Summertime Sadness"), makeTrack(title: "Winter")]
    #expect(TrackTextSearch.filter(tracks, query: "time").map(\.title) == ["Summertime Sadness"])
}

@Test func trackSearchDoesNotMatchAcrossFieldBoundaries() {
    // "close" ends title, "calvin" starts artist; a naive concatenation without
    // a separator would let "closecalvin" match.
    let tracks = [makeTrack(title: "Feel So Close", artist: "Calvin Harris")]
    #expect(TrackTextSearch.filter(tracks, query: "closecalvin").isEmpty)
}

@Test func trackSearchFileNameOnlyWhenRequested() {
    let track = makeTrack(title: "No Metadata", path: "Music/mystery-track-xyz.mp3")

    #expect(TrackTextSearch.filter([track], query: "mystery").isEmpty)
    #expect(TrackTextSearch.filter([track], query: "mystery", includeFileName: true).count == 1)
}

@Test func trackSearchNoMatchReturnsEmpty() {
    let tracks = [makeTrack(title: "One"), makeTrack(title: "Two")]
    #expect(TrackTextSearch.filter(tracks, query: "zzzz").isEmpty)
}
