import Testing
import Foundation
@testable import EZLibraryCore

/// Opt-in performance benchmarks for large (50K-track) libraries.
///
/// These are skipped in normal test runs because they generate a large
/// synthetic `database V2` and time hot paths. Run explicitly with:
///
///     SERATO_BENCH=1 swift test --filter PerformanceBenchmark
///
/// Optionally override the track count with `SERATO_BENCH_TRACKS`.
private enum Bench {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["SERATO_BENCH"] == "1"
    }

    static var trackCount: Int {
        ProcessInfo.processInfo.environment["SERATO_BENCH_TRACKS"].flatMap { Int($0) } ?? 50_000
    }

    static func time(_ label: String, _ body: () throws -> Void) rethrows {
        let start = DispatchTime.now().uptimeNanoseconds
        try body()
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        emit(String(format: "[BENCH] %-32@ %8.1f ms", label as NSString, elapsedMs))
    }

    /// Print to stdout and append to a temp file, so numbers are recoverable
    /// regardless of how the test runner captures stdout.
    static func emit(_ line: String) {
        print(line)
        let url = URL(fileURLWithPath: "/tmp/serato_bench.txt")
        if let data = (line + "\n").data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}

// MARK: - Synthetic data generation

private func bigEndian32(_ value: UInt32) -> Data {
    Data([
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
    ])
}

/// Builds a realistic in-memory `database V2` blob with `count` `otrk`
/// records, mirroring the field set the app actually reads.
private func makeSyntheticDatabase(trackCount count: Int) -> (data: Data, storedPaths: [String]) {
    let genres = ["House", "Techno", "Disco", "Hip Hop", "Pop", "Funk", "Soul",
                  "Drum & Bass", "Trance", "Ambient", "Rock", "Reggae",
                  "Afrobeat", "Latin", "R&B", "Electro", "Garage", "Dubstep",
                  "Breaks", "Downtempo"]
    let keys = ["1A", "2A", "3A", "4A", "5A", "6A", "7A", "8A", "9A", "10A", "11A", "12A"]

    var out = Data()
    // Version header chunk (ignored by parseTracks but present in real files).
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

/// Builds synthetic crates that collectively reference the given paths,
/// with two levels of nesting, to exercise `CrateHierarchy.build`.
private func makeSyntheticCrates(storedPaths: [String], crateCount: Int) -> [Crate] {
    guard !storedPaths.isEmpty else { return [] }
    var crates: [Crate] = []
    crates.reserveCapacity(crateCount)
    let perCrate = max(1, storedPaths.count / crateCount)
    for c in 0..<crateCount {
        let start = (c * perCrate) % storedPaths.count
        let end = min(start + perCrate, storedPaths.count)
        let paths = Array(storedPaths[start..<end])
        let top = "GENRE GROUP \(c % 12)"
        let child = "Crate \(c)"
        crates.append(Crate(pathComponents: [top, child], trackPaths: paths))
    }
    return crates
}

// MARK: - Benchmarks

@Test func benchmarkLibraryLoadAt50K() throws {
    guard Bench.isEnabled else { return }
    let count = Bench.trackCount

    Bench.emit("[BENCH] ---- library load @ \(count) tracks ----")

    // Generate + write a synthetic database to a temp file (measures the
    // real on-disk read path parseTracks(at:) uses).
    let (data, storedPaths) = makeSyntheticDatabase(trackCount: count)
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("serato-bench-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let dbFile = tempDir.appendingPathComponent("database V2")
    try data.write(to: dbFile)
    let root = URL(fileURLWithPath: "/Volumes/Library")
    Bench.emit(String(format: "[BENCH] database size %.1f MB", Double(data.count) / 1_048_576))

    var tracks: [Track] = []
    try Bench.time("parseTracks (disk read + decode)") {
        tracks = try SeratoDatabaseParser.parseTracks(at: dbFile, rootDirectory: root)
    }
    #expect(tracks.count == count)

    // Derived stats recomputed on every reload() (LibraryService).
    Bench.time("derive trackGenres + artistCount") {
        _ = Array(Set(tracks.map(\.genre).filter { !$0.isEmpty })).sorted()
        _ = Set(tracks.map(\.artist).filter { !$0.isEmpty }).count
    }

    let crates = makeSyntheticCrates(storedPaths: storedPaths, crateCount: 800)
    Bench.time("tracksInCratesCount (Set flatMap)") {
        _ = Set(crates.lazy.flatMap(\.trackPaths)).count
    }

    Bench.time("CrateHierarchy.build (800 crates)") {
        _ = CrateHierarchy.build(from: crates)
    }
}
