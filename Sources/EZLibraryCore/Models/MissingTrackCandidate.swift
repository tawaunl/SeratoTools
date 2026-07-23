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

/// A track whose `fileURL` no longer exists on disk, plus any candidate
/// replacement files found by filename during a `FileSystemScanner` pass.
public struct MissingTrackCandidate: Identifiable, Hashable {
    public var id: UUID { track.id }
    public let track: Track
    public var matches: [URL]

    public init(track: Track, matches: [URL] = []) {
        self.track = track
        self.matches = matches
    }
}
