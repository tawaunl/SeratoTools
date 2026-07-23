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

/// The single choke point every feature should use to rewrite a track's
/// stored path in `database V2`. Composes the Safety/ primitives in the
/// correct order — nothing else should call `AtomicFileWriter` or
/// `SeratoDatabaseWriter` directly for this purpose.
public enum SeratoPathRewriter {
    public enum RewriteError: Error, Equatable {
        /// Refuse to write while Serato itself might also be writing to
        /// the same file.
        case seratoIsRunning
        /// `oldPath` didn't match any track — failing loud here (rather
        /// than silently writing back identical bytes) surfaces caller
        /// bugs immediately instead of a mysterious no-op.
        case trackNotFound
    }

    @discardableResult
    public static func rewritePaths(
        _ rewrites: [String: String],
        in databaseFileURL: URL
    ) throws -> Int {
        guard !SeratoProcessGuard.isSeratoRunning else {
            throw RewriteError.seratoIsRunning
        }
        guard !rewrites.isEmpty else {
            return 0
        }

        try SeratoBackupBeforeWrite.snapshot(of: databaseFileURL)

        let data = try Data(contentsOf: databaseFileURL)
        let rewritten = SeratoDatabaseWriter.rewritingPaths(rewrites, in: data)
        guard rewritten.rewrittenCount > 0 else {
            throw RewriteError.trackNotFound
        }

        try AtomicFileWriter.write(rewritten.data, to: databaseFileURL)
        return rewritten.rewrittenCount
    }

    @discardableResult
    public static func rewritePath(
        _ oldPath: String,
        to newPath: String,
        in databaseFileURL: URL
    ) throws -> Bool {
        try rewritePaths([oldPath: newPath], in: databaseFileURL) > 0
    }
}
