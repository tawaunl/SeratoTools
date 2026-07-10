import Foundation

enum SeratoFeatureFlags {
    static let autoRenameFromMetadataDefaultsKey = "SeratoToolsAutoRenameFromMetadata"
    static let mainMusicFolderDefaultsKey = "YouTubeRipDestinationPath"

    static func isAutoRenameFromMetadataEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.object(forKey: autoRenameFromMetadataDefaultsKey) == nil
            ? true
            : userDefaults.bool(forKey: autoRenameFromMetadataDefaultsKey)
    }
}
