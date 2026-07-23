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
import Foundation
@testable import EZLibraryCore

@Test func databaseFileIsInsideLibraryDirectory() {
    let library = URL(fileURLWithPath: "/tmp/_Serato_")
    let database = SeratoLibraryLocator.databaseFile(in: library)
    #expect(database.lastPathComponent == "database V2")
    // Compare paths, not URLs: `deletingLastPathComponent()` appends a
    // trailing slash (file:///tmp/_Serato_/), so a raw URL `==` against the
    // slash-less library URL fails even though they're the same directory.
    #expect(database.deletingLastPathComponent().path == library.path)
}

@Test func subcrateFilesRecurseIntoRealSubdirectories() throws {
    // Regression test: the real library has `Subcrates/Serato Stems/Stems.crate`,
    // nested via an actual subdirectory rather than the `≫≫` filename
    // convention. A non-recursive enumeration misses it entirely.
    let library = Bundle.module
        .url(forResource: "Fixtures/RealLibrarySample", withExtension: nil)!
    let entries = SeratoLibraryLocator.subcrateFiles(in: library)
    let stems = try #require(entries.first { $0.url.lastPathComponent == "Stems.crate" })
    #expect(stems.directoryComponents == ["Serato Stems"])
}

@Test func smartCrateFilesAreFoundUnderSmartCratesDirectory() {
    let library = Bundle.module
        .url(forResource: "Fixtures/RealLibrarySample", withExtension: nil)!
    let entries = SeratoLibraryLocator.smartCrateFiles(in: library)
    #expect(entries.contains { $0.url.lastPathComponent == "Latest Imported.scrate" })
}
