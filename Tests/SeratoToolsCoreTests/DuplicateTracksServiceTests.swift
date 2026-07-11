import Foundation
import Testing
@testable import SeratoToolsCore

@Test func duplicateFinderSeparatesDJVersionsIntoDifferentGroups() {
    let tracks: [Track] = [
        Track(
            seratoStoredPath: "Music/Artist - Anthem.mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem.mp3"),
            title: "Anthem",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem (Copy).mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem (Copy).mp3"),
            title: "Anthem",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem (Clean).mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem (Clean).mp3"),
            title: "Anthem (Clean)",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem Clean Copy.mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem Clean Copy.mp3"),
            title: "Anthem Clean",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem (Extended Mix).mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem (Extended Mix).mp3"),
            title: "Anthem (Extended Mix)",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem Extended Copy.mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem Extended Copy.mp3"),
            title: "Anthem Extended",
            artist: "Artist"
        )
    ]

    let groups = DuplicateTracksService.duplicateGroups(in: tracks)

    #expect(groups.count == 3)
    #expect(groups.contains { $0.versionLabel == "Original" && $0.trackCount == 2 })
    #expect(groups.contains { $0.versionLabel == "Clean" && $0.trackCount == 2 })
    #expect(groups.contains { $0.versionLabel == "Extended" && $0.trackCount == 2 })
}

@Test func duplicateFinderKeepsQuickHitSeparateFromOriginal() {
    let tracks: [Track] = [
        Track(
            seratoStoredPath: "Music/Artist - Anthem.mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem.mp3"),
            title: "Anthem",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem (Alt Copy).mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem (Alt Copy).mp3"),
            title: "Anthem",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem Quick Hit.mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem Quick Hit.mp3"),
            title: "Anthem (Quick Hit)",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem Quick Hit Copy.mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem Quick Hit Copy.mp3"),
            title: "Anthem QuickHit",
            artist: "Artist"
        )
    ]

    let groups = DuplicateTracksService.duplicateGroups(in: tracks)

    #expect(groups.count == 2)
    #expect(groups.contains { $0.versionLabel == "Original" && $0.trackCount == 2 })
    #expect(groups.contains { $0.versionLabel == "Quick Hit" && $0.trackCount == 2 })
}

@Test func duplicateSummaryCountsRedundantTracks() {
    let tracks: [Track] = [
        Track(
            seratoStoredPath: "Music/Artist - Anthem.mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem.mp3"),
            title: "Anthem",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem Copy.mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem Copy.mp3"),
            title: "Anthem",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem (Clean).mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem (Clean).mp3"),
            title: "Anthem (Clean)",
            artist: "Artist"
        ),
        Track(
            seratoStoredPath: "Music/Artist - Anthem (Clean) Copy.mp3",
            fileURL: URL(fileURLWithPath: "/tmp/Artist - Anthem (Clean) Copy.mp3"),
            title: "Anthem Clean",
            artist: "Artist"
        )
    ]

    let summary = DuplicateTracksService.summary(for: tracks)

    #expect(summary.totalTracks == 4)
    #expect(summary.duplicateGroupCount == 2)
    #expect(summary.redundantTrackCount == 2)
    #expect(summary.versionSeparatedGroupCount == 1)
}