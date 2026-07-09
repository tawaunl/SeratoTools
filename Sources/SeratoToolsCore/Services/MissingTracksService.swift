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
    private let fileManager: FileManager

    public init(rootDirectory: URL, databaseFileURL: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.databaseFileURL = databaseFileURL
        self.fileManager = fileManager
    }

    /// Cheap and synchronous: just a `fileExists` check per track, no disk
    /// walk. Call this before `scanForMatches` so the UI can show the
    /// missing list immediately.
    public func detectMissingTracks(in tracks: [Track]) {
        candidates = tracks
            .filter { !fileManager.fileExists(atPath: $0.fileURL.path) }
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

    /// Returns the best match that lives inside `preferredDirectory`.
    /// If no candidate match is found under that directory, returns `nil`.
    public func preferredMatch(for candidate: MissingTrackCandidate, preferredDirectory: URL) -> URL? {
        let preferredPath = normalizedDirectoryPath(preferredDirectory)
        let prefix = preferredPath == "/" ? "/" : preferredPath + "/"

        let preferredMatches = candidate.matches
            .filter { fileManager.fileExists(atPath: $0.path) }
            .filter { match in
                let path = match.standardizedFileURL.resolvingSymlinksInPath().path
                return path == preferredPath || path.hasPrefix(prefix)
            }
            .sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }

        return preferredMatches.first
    }

    /// Rewrites every currently-missing track that has a confirmed existing
    /// match under `preferredDirectory`.
    ///
    /// Tracks without a preferred-location match are intentionally skipped and
    /// left unchanged.
    @discardableResult
    public func repairAllUsingPreferredLocation(_ preferredDirectory: URL) throws -> Int {
        var rewrites: [String: String] = [:]
        var repairedCandidateIDs = Set<UUID>()

        for candidate in candidates {
            guard let preferred = preferredMatch(for: candidate, preferredDirectory: preferredDirectory) else {
                continue
            }

            let newPath = SeratoLibraryLocator.seratoStoredPath(for: preferred, rootDirectory: rootDirectory)
            rewrites[candidate.track.seratoStoredPath] = newPath
            repairedCandidateIDs.insert(candidate.id)
        }

        guard !rewrites.isEmpty else {
            return 0
        }

        let rewrittenCount = try SeratoPathRewriter.rewritePaths(rewrites, in: databaseFileURL)
        candidates.removeAll { repairedCandidateIDs.contains($0.id) }
        return rewrittenCount
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
        while fileManager.fileExists(atPath: destination.path) {
            suffix += 1
            destination = subcratesDirectory.appendingPathComponent("Missing Tracks \(dateString) (\(suffix)).crate")
        }

        let data = SeratoCrateWriter.makeCrateData(trackPaths: candidates.map(\.track.seratoStoredPath))
        try AtomicFileWriter.write(data, to: destination)
        return destination
    }

    private func normalizedDirectoryPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
