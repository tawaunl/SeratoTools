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

@Test func searchableTermStripsTrailingDescriptors() {
    #expect(OnlineTrackMetadataLookupService.searchableTerm("Song Name (Intro)") == "Song Name")
    #expect(OnlineTrackMetadataLookupService.searchableTerm("Song Name (X) (Live)") == "Song Name")
    #expect(OnlineTrackMetadataLookupService.searchableTerm("Song Name [Intro]") == "Song Name")
    #expect(OnlineTrackMetadataLookupService.searchableTerm("Song Name") == "Song Name")
    #expect(OnlineTrackMetadataLookupService.searchableTerm("  Song Name (etc.)  ") == "Song Name")
}

@Test func titlePreservesDJDescriptorsFromOriginal() {
    // A store match (plain title) re-attaches the original's DJ descriptor.
    #expect(
        OnlineTrackMetadataLookupService.titlePreservingDescriptors(from: "Feel So Close", original: "Feel So Close (Intro)")
            == "Feel So Close (Intro)"
    )
    #expect(
        OnlineTrackMetadataLookupService.titlePreservingDescriptors(from: "Closer", original: "Closer [Clean]")
            == "Closer [Clean]"
    )
    // Multiple DJ descriptors are all preserved, in order.
    #expect(
        OnlineTrackMetadataLookupService.titlePreservingDescriptors(from: "Levels", original: "Levels (Extended) (Dirty)")
            == "Levels (Extended) (Dirty)"
    )
}

@Test func titlePreserveIgnoresNonDJParentheticals() {
    // Featured-artist / non-DJ parentheticals are not re-attached.
    #expect(
        OnlineTrackMetadataLookupService.titlePreservingDescriptors(from: "Stay", original: "Stay (feat. Justin Bieber)")
            == "Stay"
    )
    #expect(
        OnlineTrackMetadataLookupService.titlePreservingDescriptors(from: "Title", original: "Title (2019 Remaster)")
            == "Title"
    )
}

@Test func titlePreserveDoesNotDuplicateExistingDescriptor() {
    // The candidate already carries the descriptor — don't duplicate it.
    #expect(
        OnlineTrackMetadataLookupService.titlePreservingDescriptors(from: "Song (Intro)", original: "Song (Intro)")
            == "Song (Intro)"
    )
    #expect(
        OnlineTrackMetadataLookupService.titlePreservingDescriptors(from: "Song (Clean Edit)", original: "Song (Clean)")
            == "Song (Clean Edit)"
    )
}
