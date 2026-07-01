import Foundation

/// Locates the on-disk layout of a user's Serato library (`_Serato_` folder)
/// and resolves the path convention Serato uses inside `database V2`/`.crate`
/// files.
public enum SeratoLibraryLocator {
    /// A crate (or smart crate) file found on disk, along with the
    /// directory path it was nested under relative to its container
    /// (`Subcrates/` or `SmartCrates/`). Serato nests crates two ways: via
    /// an actual subdirectory (e.g. `Subcrates/Serato Stems/Stems.crate`)
    /// or via a `≫≫`-delimited filename (e.g.
    /// `SmartCrates/ALL GENRES≫≫Disco.scrate`) — both were confirmed
    /// against a real library. `directoryComponents` only captures the
    /// first kind; combine with `Crate.pathComponents(forCrateFileNamed:)`
    /// for the second.
    public struct CrateFileEntry {
        public let url: URL
        public let directoryComponents: [String]
    }

    /// Default `_Serato_` directory under `~/Music`.
    public static var defaultLibraryDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music")
            .appendingPathComponent("_Serato_")
    }

    public static func databaseFile(in libraryDirectory: URL = defaultLibraryDirectory) -> URL {
        libraryDirectory.appendingPathComponent("database V2")
    }

    public static func subcratesDirectory(in libraryDirectory: URL = defaultLibraryDirectory) -> URL {
        libraryDirectory.appendingPathComponent("Subcrates")
    }

    public static func smartCratesDirectory(in libraryDirectory: URL = defaultLibraryDirectory) -> URL {
        // Confirmed against a real library: the on-disk folder name has no
        // space ("SmartCrates"), unlike the unverified "Smart Crates"
        // constant some other Serato format implementations use.
        libraryDirectory.appendingPathComponent("SmartCrates")
    }

    public static func subcrateFiles(in libraryDirectory: URL = defaultLibraryDirectory) -> [CrateFileEntry] {
        crateFileEntries(in: subcratesDirectory(in: libraryDirectory), extension: "crate")
    }

    public static func smartCrateFiles(in libraryDirectory: URL = defaultLibraryDirectory) -> [CrateFileEntry] {
        crateFileEntries(in: smartCratesDirectory(in: libraryDirectory), extension: "scrate")
    }

    /// Recursively finds files with `extension` under `directory`, since
    /// Serato allows nesting crates in real subdirectories in addition to
    /// its `≫≫`-delimited filename convention.
    private static func crateFileEntries(in directory: URL, extension fileExtension: String) -> [CrateFileEntry] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        // Resolve symlinks on both sides before comparing path components:
        // the enumerator's URLs and a separately-standardized `directory`
        // can disagree (e.g. `/var` vs. its real `/private/var` target for
        // temp directories), which silently corrupts a plain
        // `suffix(from:)` component count.
        let baseComponents = directory.resolvingSymlinksInPath().standardizedFileURL.pathComponents

        var entries: [CrateFileEntry] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == fileExtension else { continue }
            var directoryComponents = url
                .deletingLastPathComponent()
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .pathComponents
            if directoryComponents.starts(with: baseComponents) {
                directoryComponents.removeFirst(baseComponents.count)
            } else {
                directoryComponents = []
            }
            entries.append(CrateFileEntry(url: url, directoryComponents: directoryComponents))
        }
        return entries
    }

    /// The directory that `pfil`/`ptrk` paths stored inside this library are
    /// relative to.
    ///
    /// Serato stores paths without a leading separator: for a library on the
    /// boot/home volume, paths are relative to the filesystem root ("/"); for
    /// a library on an external volume, paths are relative to that volume's
    /// mount point (the parent directory of `_Serato_`).
    public static func rootDirectory(
        for libraryDirectory: URL = defaultLibraryDirectory,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let volumeRoot = libraryDirectory.deletingLastPathComponent()
        let resolvedVolumeRoot = volumeRoot.resolvingSymlinksInPath().standardizedFileURL
        let resolvedHome = homeDirectory.resolvingSymlinksInPath().standardizedFileURL
        if resolvedVolumeRoot.path.hasPrefix(resolvedHome.path) {
            return URL(fileURLWithPath: "/")
        }
        return volumeRoot
    }

    /// Resolves a raw Serato-stored path (as found in `pfil`/`ptrk`) to an
    /// absolute file URL, given the library's root directory.
    public static func resolve(seratoStoredPath: String, rootDirectory: URL) -> URL {
        rootDirectory.appendingPathComponent(seratoStoredPath)
    }

    /// Converts an absolute file URL back into the Serato-stored path
    /// convention (relative to `rootDirectory`), for writing.
    public static func seratoStoredPath(for fileURL: URL, rootDirectory: URL) -> String {
        let rootPath = rootDirectory.standardizedFileURL.path
        var filePath = fileURL.standardizedFileURL.path
        if filePath.hasPrefix(rootPath) {
            filePath.removeFirst(rootPath.count)
        }
        while filePath.hasPrefix("/") {
            filePath.removeFirst()
        }
        return filePath
    }
}
