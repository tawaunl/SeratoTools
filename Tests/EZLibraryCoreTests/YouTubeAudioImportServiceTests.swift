import Foundation
import Testing
@testable import EZLibraryCore

@Test func musicVideoTitlesAreExcludedFromSuggestions() {
    #expect(YouTubeAudioImportService.isLikelyMusicVideo(title: "Artist - Song (Official Video)"))
    #expect(YouTubeAudioImportService.isLikelyMusicVideo(title: "Artist - Song [Official Music Video]"))
    #expect(YouTubeAudioImportService.isLikelyMusicVideo(title: "Artist - Song (Video)"))
    #expect(YouTubeAudioImportService.isLikelyMusicVideo(title: "Song M/V"))
}

@Test func audioTitlesAreKeptInSuggestions() {
    #expect(!YouTubeAudioImportService.isLikelyMusicVideo(title: "Artist - Song (Official Audio)"))
    #expect(!YouTubeAudioImportService.isLikelyMusicVideo(title: "Artist - Song (Extended Mix)"))
    #expect(!YouTubeAudioImportService.isLikelyMusicVideo(title: "Artist - Song (Intro)"))
    #expect(!YouTubeAudioImportService.isLikelyMusicVideo(title: "Artist - Song (Someone Remix)"))
    #expect(!YouTubeAudioImportService.isLikelyMusicVideo(title: "Artist - Song (Lyric Video)"))
}
