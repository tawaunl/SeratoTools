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

/// Tracks which duplicate groups and individual tracks the user wants excluded
/// from the Duplicates view "indefinitely". Like `HiddenCrateStore`, this is a
/// local app preference (UserDefaults) and never mutates Serato files, so it's
/// fully reversible.
///
/// "Ignore this time" (a single session) is deliberately not stored here — the
/// view keeps that in transient state so it clears on relaunch.
@MainActor
public final class DuplicateIgnoreStore: ObservableObject {
    private static let groupsDefaultsKey = "com.seratotools.ignoredDuplicateGroupIDs"
    private static let tracksDefaultsKey = "com.seratotools.ignoredDuplicateTrackPaths"

    /// Stable duplicate-group keys (artist|title|version) ignored indefinitely.
    @Published public private(set) var ignoredGroupIDs: Set<String>
    /// Serato stored paths of individual tracks ignored indefinitely.
    @Published public private(set) var ignoredTrackPaths: Set<String>

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.ignoredGroupIDs = Set(userDefaults.stringArray(forKey: Self.groupsDefaultsKey) ?? [])
        self.ignoredTrackPaths = Set(userDefaults.stringArray(forKey: Self.tracksDefaultsKey) ?? [])
    }

    public func isGroupIgnored(_ groupID: String) -> Bool {
        ignoredGroupIDs.contains(groupID)
    }

    public func isTrackIgnored(_ storedPath: String) -> Bool {
        ignoredTrackPaths.contains(storedPath)
    }

    public func ignoreGroup(_ groupID: String) {
        guard ignoredGroupIDs.insert(groupID).inserted else { return }
        persistGroups()
    }

    public func restoreGroup(_ groupID: String) {
        guard ignoredGroupIDs.remove(groupID) != nil else { return }
        persistGroups()
    }

    public func ignoreTrack(_ storedPath: String) {
        guard ignoredTrackPaths.insert(storedPath).inserted else { return }
        persistTracks()
    }

    public func restoreTrack(_ storedPath: String) {
        guard ignoredTrackPaths.remove(storedPath) != nil else { return }
        persistTracks()
    }

    public func restoreAll() {
        let hadItems = !ignoredGroupIDs.isEmpty || !ignoredTrackPaths.isEmpty
        guard hadItems else { return }
        ignoredGroupIDs.removeAll()
        ignoredTrackPaths.removeAll()
        persistGroups()
        persistTracks()
    }

    private func persistGroups() {
        userDefaults.set(Array(ignoredGroupIDs), forKey: Self.groupsDefaultsKey)
    }

    private func persistTracks() {
        userDefaults.set(Array(ignoredTrackPaths), forKey: Self.tracksDefaultsKey)
    }
}
