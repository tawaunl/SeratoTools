import SwiftUI
import AppKit
import SeratoToolsCore

struct LibraryConsolidationView: View {
    @EnvironmentObject private var libraryService: LibraryService

    let onLibraryChanged: () -> Void

    @State private var destinationPath = ""
    @State private var transferMode: LibraryConsolidationService.FileTransferMode = .move
    @State private var preview: LibraryConsolidationPreview?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isRunning = false
    @State private var destinationAvailableBytes: Int64?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                summaryRow
                destinationCard
                sourceGroupsCard
                destinationSpaceCard
            }
            .padding(16)
        }
        .task {
            if destinationPath.isEmpty {
                destinationPath = defaultDestinationFolder.path
            }
            refreshPreview()
            refreshDestinationCapacity()
        }
        .onChange(of: libraryService.tracks.count) {
            refreshPreview()
        }
        .onChange(of: destinationPath) {
            refreshDestinationCapacity()
        }
    }

    private var defaultDestinationFolder: URL {
        libraryService.libraryDirectory
    }

    private var currentDestinationURL: URL {
        let trimmed = destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return defaultDestinationFolder
        }
        return URL(fileURLWithPath: trimmed)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Library Consolidation")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Map where your music is scattered, then copy or move everything into one central folder while rewriting Serato paths so crates and library references stay intact.")
                .foregroundStyle(.secondary)

            if let successMessage {
                Text(successMessage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.18), Color(nsColor: .windowBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
        )
    }

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Central Folder")
                .font(.headline)

            Picker("Transfer Mode", selection: $transferMode) {
                Text("Move Files").tag(LibraryConsolidationService.FileTransferMode.move)
                Text("Copy Files").tag(LibraryConsolidationService.FileTransferMode.copy)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                TextField("Destination folder", text: $destinationPath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse…") {
                    chooseDestinationFolder()
                }
                Button("Refresh Preview") {
                    refreshPreview()
                }
                .disabled(isRunning)
                Button(actionButtonTitle) {
                    runConsolidation()
                }
                .disabled(shouldDisableConsolidationAction)
            }

            Text("Destination: \(currentDestinationURL.path)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if transferMode == .copy, isCopyBlockedByCapacity {
                Text(copyModeDisableReason)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.55)))
    }

    private var summaryRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Source Stats")
                .font(.headline)

            HStack(spacing: 10) {
                summaryTag(title: "Source Locations", value: "\(preview?.sourceGroups.count ?? 0)", accent: true)
                summaryTag(title: "Tracks To Process", value: "\(preview?.totalMoves ?? 0)", accent: true)
                summaryTag(title: transferMode == .copy ? "Will Copy" : "Will Move", value: formatGB(preview?.queuedTransferBytes ?? 0), accent: true)
            }

            HStack(spacing: 10) {
                summaryTag(title: "Library Size", value: formatGB(preview?.totalExistingBytes ?? 0))
                summaryTag(title: "Already Centralized", value: formatGB(preview?.alreadyConsolidatedBytes ?? 0))
                summaryTag(title: "Copy Space Needed", value: formatGB(copyModeRequiredBytes))
            }
        }
    }

    private var destinationSpaceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Destination Capacity")
                .font(.headline)

            HStack(spacing: 10) {
                summaryTag(title: "Destination Free", value: destinationAvailableBytes.map(formatGB) ?? "Unknown")
                summaryTag(title: "Copy Space Needed", value: formatGB(copyModeRequiredBytes))
                summaryTag(title: "Space Check", value: spaceStatusLabel, accent: hasEnoughSpaceForCopy)
                Spacer(minLength: 0)
            }

            Text(spaceStatusDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.55)))
    }

    private var sourceGroupsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Music Sources")
                .font(.headline)

            if let preview, !preview.sourceGroups.isEmpty {
                VStack(spacing: 8) {
                    ForEach(preview.sourceGroups) { group in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.title)
                                    .font(.body.weight(.semibold))
                                Text(group.examplePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(group.trackCount) tracks")
                                    .font(.body.weight(.semibold))
                                Text(formatGB(group.totalBytes))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
                    }
                }
            } else {
                Text("No track files are queued for movement with the current destination.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.55)))
    }

    private func summaryTag(title: String, value: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(accent ? .white.opacity(0.92) : .secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent ? .white : .primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(accent ? Color.accentColor.opacity(0.92) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    private func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.directoryURL = currentDestinationURL.deletingLastPathComponent()

        if panel.runModal() == .OK, let url = panel.url {
            destinationPath = url.path
            refreshPreview()
        }
    }

    private var actionButtonTitle: String {
        transferMode == .copy ? "Copy + Update Serato" : "Move + Update Serato"
    }

    private var shouldDisableConsolidationAction: Bool {
        if isRunning || (preview?.moves.isEmpty ?? true) {
            return true
        }
        return isCopyBlockedByCapacity
    }

    private var copyModeRequiredBytes: Int64 {
        preview?.queuedTransferBytes ?? 0
    }

    private var hasEnoughSpaceForCopy: Bool {
        guard let available = destinationAvailableBytes else { return false }
        return available >= copyModeRequiredBytes
    }

    private var isCopyBlockedByCapacity: Bool {
        guard transferMode == .copy else { return false }
        guard let available = destinationAvailableBytes else { return false }
        return available < copyModeRequiredBytes
    }

    private var spaceStatusLabel: String {
        guard destinationAvailableBytes != nil else {
            return "Unknown"
        }
        return hasEnoughSpaceForCopy ? "Enough" : "Insufficient"
    }

    private var spaceStatusDetail: String {
        guard let available = destinationAvailableBytes else {
            return "Could not read destination volume free space."
        }

        if hasEnoughSpaceForCopy {
            let headroom = available - copyModeRequiredBytes
            return "Copy mode has enough free space with about \(formatGB(headroom)) headroom."
        }

        let shortfall = copyModeRequiredBytes - available
        return "Copy mode is short by about \(formatGB(shortfall)). Choose a different destination or free up disk space."
    }

    private var copyModeDisableReason: String {
        guard let available = destinationAvailableBytes, available < copyModeRequiredBytes else {
            return ""
        }

        let shortfall = copyModeRequiredBytes - available
        return "Copy disabled: destination is short by about \(formatGB(shortfall))."
    }

    private func formatGB(_ bytes: Int64) -> String {
        let gigabytes = Double(bytes) / 1_073_741_824
        return String(format: "%.2f GB", gigabytes)
    }

    private func refreshPreview() {
        errorMessage = nil
        successMessage = nil
        preview = LibraryConsolidationService.preview(
            tracks: libraryService.tracks,
            destinationFolderURL: currentDestinationURL
        )
    }

    private func refreshDestinationCapacity() {
        let referenceURL = existingAncestor(of: currentDestinationURL) ?? currentDestinationURL
        destinationAvailableBytes = detectedAvailableBytes(at: referenceURL)
    }

    private func detectedAvailableBytes(at referenceURL: URL) -> Int64? {
        let candidateFromResourceValues: Int64? = {
            do {
                let values = try referenceURL.resourceValues(forKeys: [
                    .volumeAvailableCapacityForImportantUsageKey,
                    .volumeAvailableCapacityForOpportunisticUsageKey,
                    .volumeAvailableCapacityKey
                ])
                if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
                    return important
                }
                if let opportunistic = values.volumeAvailableCapacityForOpportunisticUsage, opportunistic > 0 {
                    return opportunistic
                }
                if let legacy = values.volumeAvailableCapacity, legacy > 0 {
                    return Int64(legacy)
                }
                return nil
            } catch {
                return nil
            }
        }()

        if let candidateFromResourceValues {
            return candidateFromResourceValues
        }

        // Fallback: file-system attributes are more reliable on some mounted
        // volumes and sandboxed contexts where URL resource values can report 0.
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: referenceURL.path),
           let freeSizeNumber = attributes[.systemFreeSize] as? NSNumber {
            let freeBytes = freeSizeNumber.int64Value
            if freeBytes > 0 {
                return freeBytes
            }
        }

        return nil
    }

    private func existingAncestor(of url: URL) -> URL? {
        var candidate = url.standardizedFileURL
        let fileManager = FileManager.default

        while candidate.path != "/" {
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            candidate = candidate.deletingLastPathComponent()
        }

        return URL(fileURLWithPath: "/")
    }

    private func runConsolidation() {
        guard let preview else {
            refreshPreview()
            return
        }

        errorMessage = nil
        successMessage = nil
        isRunning = true
        defer { isRunning = false }

        do {
            let result = try LibraryConsolidationService.consolidate(
                preview: preview,
                mode: transferMode,
                crates: libraryService.crates,
                rootDirectory: libraryService.rootDirectory,
                databaseFileURL: libraryService.databaseFile
            )
            let verb = result.mode == .copy ? "Copied" : "Moved"
            successMessage = "\(verb) \(result.processedTrackCount) track files into \(result.destinationFolderURL.lastPathComponent) and updated \(result.updatedCrateCount) crates."
            onLibraryChanged()
            refreshPreview()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}