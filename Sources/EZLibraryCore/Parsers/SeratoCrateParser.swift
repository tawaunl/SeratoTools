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

/// Parses a single Serato `.crate` file: a `vrsn` header, `ovct`
/// column-view metadata, and one `otrk` chunk per track containing a
/// nested `ptrk` (track path) field.
///
/// Field tags cross-checked against Mixxx's open-source Serato crate
/// reader (`src/library/serato/seratofeature.cpp`).
public enum SeratoCrateParser {
    public enum ParserError: Error {
        case fileNotFound(URL)
    }

    public static func parseCrate(at fileURL: URL) throws -> Crate {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ParserError.fileNotFound(fileURL)
        }
        let data = try Data(contentsOf: fileURL)
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        return Crate(
            pathComponents: Crate.pathComponents(forCrateFileNamed: baseName),
            trackPaths: trackPaths(from: data),
            fileURL: fileURL
        )
    }

    public static func trackPaths(from data: Data) -> [String] {
        SeratoChunkCodec.readChunks(from: data)
            .filter { $0.tag == "otrk" }
            .compactMap { trackPath(from: $0.payload) }
    }

    private static func trackPath(from otrkPayload: Data) -> String? {
        SeratoChunkCodec.readChunks(from: otrkPayload)
            .first(where: { $0.tag == "ptrk" })
            .map { SeratoChunkCodec.decodeUTF16BEString($0.payload) }
    }
}
