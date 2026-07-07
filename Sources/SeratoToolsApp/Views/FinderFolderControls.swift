import SwiftUI
import AppKit

struct FinderFolderControls: View {
    let label: String
    @Binding var path: String
    let browsePrompt: String
    let browseStartURL: URL
    let allowsNewFolderCreation: Bool
    let onPathChanged: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                TextField(label, text: $path)
                    .textFieldStyle(.roundedBorder)

                Button("Browse…") {
                    browseForFolder()
                }

                if allowsNewFolderCreation {
                    Button("New Folder…") {
                        createNewFolder()
                    }
                }

                Button("Open") {
                    openInFinder()
                }
                .disabled(currentFolderURL == nil)

                Button("Reveal") {
                    revealInFinder()
                }
                .disabled(currentFolderURL == nil)
            }
        }
    }

    private var currentFolderURL: URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return browseStartURL
        }

        return URL(fileURLWithPath: trimmed)
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = browsePrompt
        panel.directoryURL = currentFolderURL

        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            onPathChanged?()
        }
    }

    private func createNewFolder() {
        guard let parentURL = currentFolderURL else { return }

        let alert = NSAlert()
        alert.messageText = "Create New Folder"
        alert.informativeText = "Create a new folder inside \(parentURL.lastPathComponent)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        nameField.placeholderString = "Folder name"
        nameField.stringValue = suggestedFolderName(in: parentURL)
        alert.accessoryView = nameField

        if alert.runModal() != .alertFirstButtonReturn {
            return
        }

        let folderName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folderName.isEmpty else { return }

        let createdURL = parentURL.appendingPathComponent(folderName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: createdURL, withIntermediateDirectories: false)
            path = createdURL.path
            onPathChanged?()
            NSWorkspace.shared.activateFileViewerSelecting([createdURL])
        } catch {
            showError(message: "Couldn't create folder: \(error.localizedDescription)")
        }
    }

    private func openInFinder() {
        guard let folderURL = currentFolderURL else { return }
        NSWorkspace.shared.open(folderURL)
    }

    private func revealInFinder() {
        guard let folderURL = currentFolderURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
    }

    private func suggestedFolderName(in parentURL: URL) -> String {
        let base = "New Folder"
        var candidate = base
        var counter = 2
        while FileManager.default.fileExists(atPath: parentURL.appendingPathComponent(candidate, isDirectory: true).path) {
            candidate = "\(base) \(counter)"
            counter += 1
        }
        return candidate
    }

    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Couldn't Create Folder"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}