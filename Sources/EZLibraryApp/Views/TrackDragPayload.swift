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

enum TrackDragPayload {
    private static let prefix = "seratotools-track-path:"

    static func encode(path: String) -> String {
        "\(prefix)\(path)"
    }

    static func decode(_ value: String) -> String? {
        guard value.hasPrefix(prefix) else { return nil }
        return String(value.dropFirst(prefix.count))
    }

    static func decodeMany(_ value: String) -> [String] {
        value
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { decode(String($0)) }
    }

    static func encodeMany(paths: [String]) -> String {
        paths
            .map(encode(path:))
            .joined(separator: "\n")
    }
}
