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

/// A single Serato crate, parsed from one `.crate` file under `Subcrates/`.
///
/// Nested crates are stored on disk as one flat file whose name encodes the
/// hierarchy with a `≫≫` (U+226B doubled) separator, e.g.
/// `ALL GENRES≫≫Disco.crate` is the "Disco" crate nested under "ALL GENRES".
/// Building the cross-crate parent/child tree from a directory of these is
/// `CrateHierarchy`'s job, not this type's — `Crate` only knows its own
/// nesting path.
public struct Crate: Identifiable, Hashable, Sendable {
    public static let nestingDelimiter = "\u{226B}\u{226B}"

    public let id: UUID

    /// This crate's own nesting path, e.g. `["ALL GENRES", "Disco"]`.
    public var pathComponents: [String]

    /// Track paths exactly as stored in the crate's `ptrk` fields — these
    /// match `Track.seratoStoredPath`, not `Track.id`, since Serato crates
    /// reference tracks by path.
    public var trackPaths: [String]

    /// The `.crate` file this was read from, or `nil` for a crate not yet
    /// written to disk.
    public var fileURL: URL?

    public var name: String { pathComponents.last ?? "" }

    public init(
        pathComponents: [String],
        trackPaths: [String] = [],
        fileURL: URL? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.pathComponents = pathComponents
        self.trackPaths = trackPaths
        self.fileURL = fileURL
    }

    /// Derives `pathComponents` from a `.crate` file's base name.
    public static func pathComponents(forCrateFileNamed baseName: String) -> [String] {
        baseName.components(separatedBy: nestingDelimiter)
    }

    /// The on-disk base file name (without extension) for `pathComponents`.
    public static func fileBaseName(forPathComponents pathComponents: [String]) -> String {
        pathComponents.joined(separator: nestingDelimiter)
    }
}
