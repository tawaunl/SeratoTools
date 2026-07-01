import Foundation

/// Detects tracks whose audio file no longer exists on disk ("orange"/broken
/// in Serato), finds candidate replacements by filename, and repairs or
/// gathers them for review.
///
/// Ground truth for "is this track missing" is `FileManager.fileExists` on
/// `Track.fileURL` — Serato's own `bmis` flag (`Track.isMissing`) can be
/// stale, so it's intentionally not consulted here.
@MainActor
public final class MissingTracksService: ObservableObject {
    @Published public private(set) var candidates: [MissingTrackCandidate] = []
    @Published public private(set) var isScanning = false

    private let rootDirectory: URL
    private let databaseFileURL: URL

    public init(rootDirectory: URL, databaseFileURL: URL) {
        self.rootDirectory = rootDirectory
        self.databaseFileURL = databaseFileURL
    }

    /// Cheap and synchronous: just a `fileExists` check per track, no disk
    /// walk. Call this before `scanForMatches` so the UI can show the
    /// missing list immediately.
    public func detectMissingTracks(in tracks: [Track]) {
        candidates = tracks
            .filter { !FileManager.default.fileExists(atPath: $0.fileURL.path) }
            .map { MissingTrackCandidate(track: $0) }
    }

    /// Builds a filename index once across `roots`, then fills in
    /// `matches` for every current candidate. Runs off the main actor since
    /// a full scan can take real time.
    public func scanForMatches(roots: [URL] = FileSystemScanner.defaultScanRoots) async {
        guard !candidates.isEmpty else { return }
        isScanning = true
        defer { isScanning = false }

        let index = await Task.detached(priority: .userInitiated) {
            FileSystemScanner.scanRoots(roots)
        }.value

        candidates = candidates.map { candidate in
            var updated = candidate
            updated.matches = index.candidates(forFilename: candidate.track.fileURL.lastPathComponent)
            return updated
        }
    }

    /// Rewrites the track's stored path to `replacement`, via the one safe
    /// choke point (`SeratoPathRewriter`), and drops it from `candidates`.
    /// Never called automatically — every repair is an explicit,
    /// user-confirmed action, even for a single unambiguous match.
    @discardableResult
    public func repair(_ candidate: MissingTrackCandidate, using replacement: URL) throws -> Bool {
        let newPath = SeratoLibraryLocator.seratoStoredPath(for: replacement, rootDirectory: rootDirectory)
        let didRewrite = try SeratoPathRewriter.rewritePath(
            candidate.track.seratoStoredPath, to: newPath, in: databaseFileURL
        )
        candidates.removeAll { $0.id == candidate.id }
        return didRewrite
    }

    /// Always creates a fresh, dated crate — never merges into a prior
    /// review crate, since "missing tracks" is a point-in-time snapshot and
    /// merging risks resurrecting already-fixed entries. References tracks
    /// by their still-broken path: gathering and repairing are separate
    /// actions.
    public func gatherIntoReviewCrate(subcratesDirectory: URL, date: Date = Date()) throws -> URL {
        guard !SeratoProcessGuard.isSeratoRunning else {
            throw SeratoPathRewriter.RewriteError.seratoIsRunning
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        var suffix = 1
        var destination = subcratesDirectory.appendingPathComponent("Missing Tracks \(dateString).crate")
        while FileManager.default.fileExists(atPath: destination.path) {
            suffix += 1
            destination = subcratesDirectory.appendingPathComponent("Missing Tracks \(dateString) (\(suffix)).crate")
        }

        let data = SeratoCrateWriter.makeCrateData(trackPaths: candidates.map(\.track.seratoStoredPath))
        try AtomicFileWriter.write(data, to: destination)
        return destination
    }
}
