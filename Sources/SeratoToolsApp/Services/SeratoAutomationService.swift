import Foundation
import SeratoToolsCore

struct SeratoAutomationService {
    static func triggerAnalyzeFilesIfRunning() -> String? {
        guard SeratoFeatureFlags.isAutoAnalyzeAfterWriteEnabled() else {
            return nil
        }

        guard SeratoProcessGuard.isSeratoRunning else {
            return nil
        }

        let scriptsByAppName: [(appName: String, script: [String])] = [
            (
                "Serato DJ Pro",
                [
                    "tell application \"Serato DJ Pro\" to activate",
                    "tell application \"System Events\"",
                    "tell process \"Serato DJ Pro\"",
                    "set targetItem to first menu item of menu \"Library\" of menu bar 1 whose name starts with \"Analyze\"",
                    "click targetItem",
                    "end tell",
                    "end tell"
                ]
            ),
            (
                "Serato DJ Lite",
                [
                    "tell application \"Serato DJ Lite\" to activate",
                    "tell application \"System Events\"",
                    "tell process \"Serato DJ Lite\"",
                    "set targetItem to first menu item of menu \"Library\" of menu bar 1 whose name starts with \"Analyze\"",
                    "click targetItem",
                    "end tell",
                    "end tell"
                ]
            )
        ]

        for candidate in scriptsByAppName {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = candidate.script.flatMap { ["-e", $0] }
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                continue
            }

            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return nil
            }
        }

        return "Auto Analyze could not be triggered. Grant Accessibility permission for SeratoTools and System Events in macOS Privacy settings."
    }
}
