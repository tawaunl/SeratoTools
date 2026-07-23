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

/// One node in the browsable crate tree built by `CrateHierarchy`.
///
/// Distinct from `Crate` (which only knows its own path, matching exactly
/// one file on disk): a `CrateNode` may be a synthesized folder with no
/// `.crate` file of its own, needed when an intermediate path segment
/// exists only because deeper crates reference it (e.g. "ALL GENRES" when
/// only "ALL GENRES≫≫Disco.crate" exists on disk).
public struct CrateNode: Identifiable, Hashable {
    /// Stable across reloads: the joined `pathComponents`, unlike
    /// `Crate.id` (a fresh UUID every parse) or bare `name` (collides
    /// across different parents).
    public var id: String { pathComponents.joined(separator: "/") }

    public let pathComponents: [String]
    public var crate: Crate?
    public var children: [CrateNode]

    public var name: String { pathComponents.last ?? "" }

    public init(pathComponents: [String], crate: Crate? = nil, children: [CrateNode] = []) {
        self.pathComponents = pathComponents
        self.crate = crate
        self.children = children
    }
}
