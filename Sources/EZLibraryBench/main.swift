// EZLibrary — an open source toolkit for Serato DJ libraries.
// Copyright (C) 2026 Tawaun Lucas
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version. It is distributed WITHOUT ANY WARRANTY; see the GNU
// General Public License (LICENSE) for more details.

import Foundation
import EZLibraryCore

// Repeatable performance harness for large (50K-track) Serato libraries.
//
// Generates a realistic synthetic `database V2` + crates entirely in memory,
// then times the hot paths the app runs on launch and after every library
// change. Run in release for representative end-user numbers:
//
//     swift run -c release EZLibraryBench            # 50,000 tracks
//     swift run -c release EZLibraryBench 100000     # custom count
//
// No product code depends on this target; it exists purely for profiling.

@inline(__always)
func timeIt(_ label: String, _ body: () -> Void) {
    let start = DispatchTime.now().uptimeNanoseconds
    body()
    let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    print(String(format: "  %-38@ %9.1f ms", label as NSString, ms))
}

func bigEndian32(_ value: UInt32) -> Data {
    Data([
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
    ])
}

/// Builds a realistic in-memory `database V2` blob with `count` `otrk`
/// records, mirroring the field set the app actually reads.
func makeSyntheticDatabase(trackCount count: Int) -> (data: Data, storedPaths: [String]) {
    let genres = ["House", "Techno", "Disco", "Hip Hop", "Pop", "Funk", "Soul",
                  "Drum & Bass", "Trance", "Ambient", "Rock", "Reggae",
                  "Afrobeat", "Latin", "R&B", "Electro", "Garage", "Dubstep",
                  "Breaks", "Downtempo"]
    let keys = ["1A", "2A", "3A", "4A", "5A", "6A", "7A", "8A", "9A", "10A", "11A", "12A"]

    var out = Data()
    out.append(SeratoChunkCodec.writeChunk(
        tag: "vrsn",
        payload: SeratoChunkCodec.encodeUTF16BEString("2.0/Serato Scratch LIVE Database")))

    var storedPaths: [String] = []
    storedPaths.reserveCapacity(count)
    out.reserveCapacity(count * 220)

    let baseDate = UInt32(Date().timeIntervalSince1970)

    for i in 0..<count {
        let path = "Music/Artist \(i % 5000)/Album \(i % 8000)/\(i) - Track Title Number \(i).mp3"
        storedPaths.append(path)

        var record = Data()
        func field(_ tag: String, _ value: String) {
            record.append(SeratoChunkCodec.writeChunk(
                tag: tag, payload: SeratoChunkCodec.encodeUTF16BEString(value)))
        }
        field("pfil", path)
        field("tsng", "Track Title Number \(i)")
        field("tart", "Artist \(i % 5000)")
        field("talb", "Album \(i % 8000)")
        field("tgen", genres[i % genres.count])
        field("tcom", "some comment text for track \(i)")
        field("tlbl", "Label \(i % 400)")
        field("ttyr", "\(1990 + (i % 35))")
        field("tlen", "\(180 + (i % 240))")
        field("tbit", "320")
        field("tsmp", "44100")
        field("tbpm", "\(120 + (i % 60)).0")
        field("tkey", keys[i % keys.count])
        record.append(SeratoChunkCodec.writeChunk(tag: "uadd", payload: bigEndian32(baseDate - UInt32(i))))

        out.append(SeratoChunkCodec.writeChunk(tag: "otrk", payload: record))
    }
    return (out, storedPaths)
}

/// Builds synthetic crates that collectively reference the given paths, with
/// two levels of nesting, to exercise `CrateHierarchy.build`.
func makeSyntheticCrates(storedPaths: [String], crateCount: Int) -> [Crate] {
    guard !storedPaths.isEmpty else { return [] }
    var crates: [Crate] = []
    crates.reserveCapacity(crateCount)
    let perCrate = max(1, storedPaths.count / crateCount)
    for c in 0..<crateCount {
        let start = (c * perCrate) % storedPaths.count
        let end = min(start + perCrate, storedPaths.count)
        let paths = Array(storedPaths[start..<end])
        crates.append(Crate(pathComponents: ["GENRE GROUP \(c % 12)", "Crate \(c)"], trackPaths: paths))
    }
    return crates
}

// MARK: - Run

let count = CommandLine.arguments.dropFirst().first.flatMap { Int($0) } ?? 50_000
let crateCount = 800

print("=== EZLibrary load benchmark @ \(count) tracks, \(crateCount) crates ===")

let (data, storedPaths) = makeSyntheticDatabase(trackCount: count)
print(String(format: "  database size: %.1f MB", Double(data.count) / 1_048_576))

let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("serato-bench-\(UUID().uuidString)", isDirectory: true)
try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tempDir) }
let dbFile = tempDir.appendingPathComponent("database V2")
try! data.write(to: dbFile)
let root = URL(fileURLWithPath: "/Volumes/Library")

var fileData = Data()
timeIt("raw file read (Data(contentsOf:))") {
    fileData = try! Data(contentsOf: dbFile)
}

var topLevelCount = 0
timeIt("top-level readChunks (split otrk)") {
    topLevelCount = SeratoChunkCodec.readChunks(from: fileData).count
}
print("    (top-level chunks: \(topLevelCount))")

var tracks: [Track] = []
timeIt("parseTracks (disk read + decode)") {
    tracks = try! SeratoDatabaseParser.parseTracks(at: dbFile, rootDirectory: root)
}
precondition(tracks.count == count)

timeIt("derive trackGenres + artistCount") {
    _ = Array(Set(tracks.map(\.genre).filter { !$0.isEmpty })).sorted()
    _ = Set(tracks.map(\.artist).filter { !$0.isEmpty }).count
}

let crates = makeSyntheticCrates(storedPaths: storedPaths, crateCount: crateCount)
timeIt("tracksInCratesCount (Set flatMap)") {
    _ = Set(crates.lazy.flatMap(\.trackPaths)).count
}

timeIt("CrateHierarchy.build") {
    _ = CrateHierarchy.build(from: crates)
}

// The full main-thread cost of one reload(): parse + both hierarchies +
// derived stats + tracksInCratesCount (play-count scan is already async).
timeIt("FULL reload() equivalent (main-thread)") {
    let parsed = try! SeratoDatabaseParser.parseTracks(at: dbFile, rootDirectory: root)
    _ = Array(Set(parsed.map(\.genre).filter { !$0.isEmpty })).sorted()
    _ = Set(parsed.map(\.artist).filter { !$0.isEmpty }).count
    _ = Set(crates.lazy.flatMap(\.trackPaths)).count
    _ = CrateHierarchy.build(from: crates)
}

// MARK: - TrackTableView interaction costs (mirrors the app's logic)

print("--- table interaction (\(tracks.count) rows) ---")

// Filter (search) — lowercased contains across 4 fields, as computeDisplayedTracks does.
timeIt("filter contains (query 'the')") {
    let q = "the"
    _ = tracks.filter {
        $0.title.lowercased().contains(q)
            || $0.artist.lowercased().contains(q)
            || $0.genre.lowercased().contains(q)
            || $0.album.lowercased().contains(q)
    }
}

// Candidate A: case-insensitive range search (no per-field lowercased copy).
timeIt("filter range(of:caseInsensitive)") {
    let q = "the"
    _ = tracks.filter {
        $0.title.range(of: q, options: .caseInsensitive) != nil
            || $0.artist.range(of: q, options: .caseInsensitive) != nil
            || $0.genre.range(of: q, options: .caseInsensitive) != nil
            || $0.album.range(of: q, options: .caseInsensitive) != nil
    }
}

// Candidate B: precomputed lowercased blob per track (built once), then plain contains.
var blobs: [String] = []
timeIt("build lowercased blobs (ONCE per load)") {
    blobs = tracks.map {
        var s = $0.title; s += "\n"; s += $0.artist; s += "\n"; s += $0.genre; s += "\n"; s += $0.album
        return s.lowercased()
    }
}
timeIt("filter prebuilt blobs (per keystroke)") {
    let q = "the"
    _ = blobs.indices.filter { blobs[$0].contains(q) }
}

// Candidate C: precomputed lowercased UTF-8 BYTE blobs + byte substring search
// (avoids String.contains grapheme segmentation entirely).
func byteContains(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
    guard !needle.isEmpty, needle.count <= haystack.count else { return false }
    let first = needle[0]
    let limit = haystack.count - needle.count
    var i = 0
    while i <= limit {
        if haystack[i] == first {
            var j = 1
            while j < needle.count, haystack[i + j] == needle[j] { j += 1 }
            if j == needle.count { return true }
        }
        i += 1
    }
    return false
}

var byteBlobs: [[UInt8]] = []
timeIt("build lowercased BYTE blobs (ONCE per load)") {
    byteBlobs = tracks.map {
        var s = $0.title; s += "\u{01}"; s += $0.artist; s += "\u{01}"; s += $0.genre; s += "\u{01}"; s += $0.album
        return Array(s.lowercased().utf8)
    }
}
timeIt("filter BYTE blobs (per keystroke)") {
    let needle = Array("the".utf8)
    _ = byteBlobs.indices.filter { byteContains(byteBlobs[$0], needle) }
}
// A rarer query (fewer hits) to show worst-case scan cost.
timeIt("filter BYTE blobs (rare query)") {
    let needle = Array("zxqw".utf8)
    _ = byteBlobs.indices.filter { byteContains(byteBlobs[$0], needle) }
}

// Candidate D: NON-cached — build combined blob + byte-search per keystroke
// (what TrackTextSearch.filter does without a persisted index).
timeIt("filter combined byte (build+search/keystroke)") {
    let needle = Array("the".utf8)
    _ = tracks.filter { t in
        var s = t.title; s += "\u{01}"; s += t.artist; s += "\u{01}"; s += t.album; s += "\u{01}"; s += t.genre
        return byteContains(Array(s.lowercased().utf8), needle)
    }
}

// Sort by title using the locale-aware comparison the table uses today.
timeIt("sort title (localizedCaseInsensitive)") {
    _ = tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
}

// Sort by a precomputed lowercased key (candidate optimization).
timeIt("sort title (precomputed lowercased)") {
    let keyed = tracks.map { (key: $0.title.lowercased(), track: $0) }
    _ = keyed.sorted { $0.key < $1.key }
}

// selectionKey mapping — runs once per recompute over the whole result set.
timeIt("selectionKey map (string transforms)") {
    _ = tracks.map {
        $0.seratoStoredPath
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }
}

// TracksAndTagsView per-body cascade: 8 fill-count passes (each O(n) with a
// per-element trimmingCharacters allocation) + scope/genre/displayed filters.
// ALL of this currently re-runs on every SwiftUI body evaluation.
timeIt("stats: 8x count(trimming) per body") {
    let ws = CharacterSet.whitespacesAndNewlines
    for _ in 0..<4 {
        _ = tracks.filter { !$0.artist.trimmingCharacters(in: ws).isEmpty }.count
    }
    _ = tracks.filter { !$0.album.trimmingCharacters(in: ws).isEmpty }.count
    _ = tracks.filter { !$0.genre.trimmingCharacters(in: ws).isEmpty }.count
    _ = tracks.filter { $0.year != nil }.count
    _ = tracks.filter { !$0.artist.trimmingCharacters(in: ws).isEmpty }.count
}

// Cheaper equivalent without trimming allocations (candidate optimization).
timeIt("stats: 8x count(no-trim) per body") {
    @inline(__always) func nonEmpty(_ s: String) -> Bool {
        for ch in s.unicodeScalars where !CharacterSet.whitespacesAndNewlines.contains(ch) { return true }
        return false
    }
    for _ in 0..<6 { _ = tracks.reduce(0) { nonEmpty($1.artist) ? $0 + 1 : $0 } }
    _ = tracks.reduce(0) { $1.year != nil ? $0 + 1 : $0 }
    _ = tracks.reduce(0) { nonEmpty($1.genre) ? $0 + 1 : $0 }
}


// playCountSignature — O(n) sum recomputed on EVERY SwiftUI body evaluation.
timeIt("playCountSignature (per body eval!)") {
    var sum = 0
    for t in tracks { sum = sum &+ (t.playCount ?? 0) }
    _ = sum
}

// tracksDiffer — O(n) id+playCount compare on EVERY updateNSView pass.
timeIt("tracksDiffer (per updateNSView!)") {
    var differ = false
    for i in tracks.indices where tracks[i].id != tracks[i].id || tracks[i].playCount != tracks[i].playCount {
        differ = true
    }
    _ = differ
}

