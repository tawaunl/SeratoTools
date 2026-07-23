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
import EZLibraryCore

/// Polls the user's Downloads folder for newly finished audio files so
/// PlaylistMatch can offer to import a track the moment it's downloaded from a
/// store. Only files that appear *after* `start()` are reported, and only once
/// their size has settled (so partial/in-progress downloads are ignored).
@MainActor
final class DownloadsFolderWatcher: ObservableObject {
    @Published private(set) var detectedFiles: [URL] = []

    private let folderURL: URL
    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var baseline: Set<String> = []
    private var reported: Set<String> = []
    private var pendingSizes: [String: Int] = [:]

    init(
        folderURL: URL = DownloadsFolderWatcher.defaultDownloadsFolder,
        pollInterval: TimeInterval = 3
    ) {
        self.folderURL = folderURL
        self.pollInterval = pollInterval
    }

    static var defaultDownloadsFolder: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
    }

    func start() {
        guard timer == nil else { return }
        // Everything already present is treated as pre-existing and ignored.
        baseline = Set(currentAudioFiles().map { $0.standardizedFileURL.path })

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func dismiss(_ url: URL) {
        detectedFiles.removeAll { $0 == url }
    }

    func clearDetected() {
        detectedFiles.removeAll()
    }

    private func poll() {
        let files = currentAudioFiles()
        let currentPaths = Set(files.map { $0.standardizedFileURL.path })
        // Forget pending files that vanished (e.g. renamed from a .part file).
        pendingSizes = pendingSizes.filter { currentPaths.contains($0.key) }

        for url in files {
            let path = url.standardizedFileURL.path
            if baseline.contains(path) || reported.contains(path) { continue }
            guard let size = fileSize(url), size > 0 else { continue }

            if pendingSizes[path] == size {
                // Size unchanged across a poll → download has settled.
                pendingSizes[path] = nil
                reported.insert(path)
                detectedFiles.append(url)
            } else {
                pendingSizes[path] = size
            }
        }
    }

    private func currentAudioFiles() -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )) ?? []

        return items.filter {
            AddMusicImportService.supportedAudioExtensions.contains($0.pathExtension.lowercased())
        }
    }

    private func fileSize(_ url: URL) -> Int? {
        try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }
}
