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

/// Builds the browsable parent/child crate tree from a flat list of
/// `Crate` values. Pure function, no I/O — assumes each `Crate`'s
/// `pathComponents` already fully reflects however it's nested on disk
/// (both the `≫≫`-delimited filename convention and real subdirectory
/// nesting are normalized into `pathComponents` upstream, in
/// `LibraryService`, before this ever runs).
public enum CrateHierarchy {
    public static func build(from crates: [Crate]) -> [CrateNode] {
        let root = Builder(pathComponents: [])
        for crate in crates where !crate.pathComponents.isEmpty {
            var node = root
            var prefix: [String] = []
            for component in crate.pathComponents {
                prefix.append(component)
                if let existing = node.childrenByName[component] {
                    node = existing
                } else {
                    let child = Builder(pathComponents: prefix)
                    node.childrenByName[component] = child
                    node.orderedChildNames.append(component)
                    node = child
                }
            }
            node.crate = crate
        }
        return root.freeze().children
    }

    private final class Builder {
        let pathComponents: [String]
        var crate: Crate?
        var childrenByName: [String: Builder] = [:]
        var orderedChildNames: [String] = []

        init(pathComponents: [String]) {
            self.pathComponents = pathComponents
        }

        func freeze() -> CrateNode {
            let children = orderedChildNames
                .compactMap { childrenByName[$0] }
                .sorted { $0.pathComponents.last! < $1.pathComponents.last! }
                .map { $0.freeze() }
            return CrateNode(pathComponents: pathComponents, crate: crate, children: children)
        }
    }
}
