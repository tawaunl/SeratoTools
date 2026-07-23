// EZLibrary — an open source toolkit for Serato DJ libraries.
// Copyright (C) 2026 Tawaun Lucas
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version. It is distributed WITHOUT ANY WARRANTY; see the GNU
// General Public License (LICENSE) for more details.

import Testing
@testable import EZLibraryCore

@Test func buildsFlatTreeForUnnestedCrates() {
    let crates = [
        Crate(pathComponents: ["Recorded"]),
        Crate(pathComponents: ["Pride mix"])
    ]
    let tree = CrateHierarchy.build(from: crates)
    #expect(tree.map(\.name) == ["Pride mix", "Recorded"])
    #expect(tree.allSatisfy { $0.children.isEmpty })
}

@Test func synthesizesFolderNodeForMissingIntermediateCrate() {
    // Only "ALL GENRES≫≫Disco.crate" exists on disk — no bare
    // "ALL GENRES.crate" — so "ALL GENRES" must be a synthesized
    // folder-only node with `crate == nil`.
    let crates = [Crate(pathComponents: ["ALL GENRES", "Disco"])]
    let tree = CrateHierarchy.build(from: crates)

    #expect(tree.count == 1)
    let allGenres = tree[0]
    #expect(allGenres.name == "ALL GENRES")
    #expect(allGenres.crate == nil)
    #expect(allGenres.children.map(\.name) == ["Disco"])
    #expect(allGenres.children[0].crate != nil)
}

@Test func directoryNestedPathAlreadyFlattenedBuildsSameShapeAsDelimiterNesting() {
    // CrateHierarchy doesn't care which mechanism produced pathComponents
    // (real subdirectory vs. `≫≫` filename) — both arrive pre-flattened.
    let crates = [Crate(pathComponents: ["Serato Stems", "Stems"])]
    let tree = CrateHierarchy.build(from: crates)

    #expect(tree.count == 1)
    #expect(tree[0].name == "Serato Stems")
    #expect(tree[0].children.map(\.name) == ["Stems"])
}

@Test func realCrateWithChildrenIsBothALeafAndAParent() {
    // A crate file can exist AND have deeper nested crates underneath it
    // (e.g. "ALL GENRES.crate" plus "ALL GENRES≫≫Disco.crate").
    let crates = [
        Crate(pathComponents: ["ALL GENRES"], trackPaths: ["Music/a.mp3"]),
        Crate(pathComponents: ["ALL GENRES", "Disco"])
    ]
    let tree = CrateHierarchy.build(from: crates)

    #expect(tree.count == 1)
    #expect(tree[0].crate?.trackPaths == ["Music/a.mp3"])
    #expect(tree[0].children.map(\.name) == ["Disco"])
}
