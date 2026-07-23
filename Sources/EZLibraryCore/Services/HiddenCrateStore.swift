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

/// Tracks which crates the user has hidden from `CrateView` — a local app
/// preference, never a Serato file mutation, so it's reversible with a
/// one-click unhide.
@MainActor
public final class HiddenCrateStore: ObservableObject {
    private static let defaultsKey = "com.seratotools.hiddenCrateIDs"

    @Published public private(set) var hiddenIDs: Set<String>

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hiddenIDs = Set(userDefaults.stringArray(forKey: Self.defaultsKey) ?? [])
    }

    /// A node is hidden if its own path is hidden, or any ancestor's is —
    /// hiding a folder hides everything nested under it.
    public func isHidden(_ node: CrateNode) -> Bool {
        var prefix: [String] = []
        for component in node.pathComponents {
            prefix.append(component)
            if hiddenIDs.contains(prefix.joined(separator: "/")) {
                return true
            }
        }
        return false
    }

    public func hide(_ node: CrateNode) {
        hiddenIDs.insert(node.id)
        persist()
    }

    public func unhide(_ node: CrateNode) {
        hiddenIDs.remove(node.id)
        persist()
    }

    private func persist() {
        userDefaults.set(Array(hiddenIDs), forKey: Self.defaultsKey)
    }
}
