import Foundation

enum SeratoFeatureFlags {
    static let autoAnalyzeAfterWriteDefaultsKey = "SeratoToolsAutoAnalyzeAfterWrite"
    static let autoRenameFromMetadataDefaultsKey = "SeratoToolsAutoRenameFromMetadata"

    static func isAutoAnalyzeAfterWriteEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.object(forKey: autoAnalyzeAfterWriteDefaultsKey) == nil
            ? true
            : userDefaults.bool(forKey: autoAnalyzeAfterWriteDefaultsKey)
    }

    static func isAutoRenameFromMetadataEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.object(forKey: autoRenameFromMetadataDefaultsKey) == nil
            ? true
            : userDefaults.bool(forKey: autoRenameFromMetadataDefaultsKey)
    }
}
