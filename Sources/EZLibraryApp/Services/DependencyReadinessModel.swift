// EZLibrary — an open source toolkit for Serato DJ libraries.
// Copyright (C) 2026 Tawaun Lucas
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version. It is distributed WITHOUT ANY WARRANTY; see the GNU
// General Public License (LICENSE) for more details.

import SwiftUI
import EZLibraryCore

/// Drives the launch-time dependency readiness check and the banner that lets
/// the user install or update the Homebrew-managed command-line tools.
@MainActor
final class DependencyReadinessModel: ObservableObject {
    @Published private(set) var report: RuntimeDependencyService.Report?
    @Published private(set) var isChecking = false
    @Published private(set) var isInstalling = false
    @Published private(set) var lastActionLog: String?
    @Published var isBannerDismissed = false

    /// Whether the readiness banner should currently be visible.
    var shouldShowBanner: Bool {
        if isInstalling { return true }
        guard !isBannerDismissed, let report else { return false }
        return report.needsAttention
    }

    /// Runs the readiness check every time the app launches.
    func checkOnLaunch() async {
        await refresh()
    }

    /// Re-evaluates readiness in the background and updates published state.
    func refresh() async {
        guard !isChecking else { return }
        isChecking = true
        let evaluated = await Task.detached(priority: .utility) {
            RuntimeDependencyService.evaluate()
        }.value
        report = evaluated
        // Re-surface the banner whenever a new problem appears.
        if evaluated.needsAttention {
            isBannerDismissed = false
        }
        isChecking = false
    }

    /// Installs missing tools and upgrades outdated ones, then re-evaluates.
    func installOrUpdate() async {
        guard !isInstalling else { return }
        isInstalling = true
        let result = await Task.detached(priority: .userInitiated) {
            RuntimeDependencyService.ensureReady()
        }.value
        report = result.report
        lastActionLog = result.log.isEmpty ? nil : result.log
        isInstalling = false
        if result.report.isFullyReady {
            isBannerDismissed = true
        }
    }
}
