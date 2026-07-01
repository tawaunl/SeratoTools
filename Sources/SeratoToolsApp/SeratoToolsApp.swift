import SwiftUI
import SeratoToolsCore

@main
struct SeratoToolsApp: App {
    @StateObject private var libraryService: LibraryService
    @StateObject private var hiddenCrateStore: HiddenCrateStore
    @StateObject private var crateHierarchy: CrateHierarchyViewModel
    @StateObject private var smartCrateHierarchy: CrateHierarchyViewModel
    @StateObject private var missingTracksService: MissingTracksService

    init() {
        // A DEBUG-only override so Phase 1 can be smoke-tested against a
        // scratch copy of a real library without touching the user's live
        // ~/Music/_Serato_.
        var libraryDirectory = SeratoLibraryLocator.defaultLibraryDirectory
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["SERATOTOOLS_LIBRARY_DIR"] {
            libraryDirectory = URL(fileURLWithPath: override)
        }
        #endif

        let library = LibraryService(libraryDirectory: libraryDirectory)
        let hiddenStore = HiddenCrateStore()
        _libraryService = StateObject(wrappedValue: library)
        _hiddenCrateStore = StateObject(wrappedValue: hiddenStore)
        _crateHierarchy = StateObject(
            wrappedValue: CrateHierarchyViewModel(hiddenStore: hiddenStore, allowsDelete: true)
        )
        _smartCrateHierarchy = StateObject(
            wrappedValue: CrateHierarchyViewModel(hiddenStore: hiddenStore, allowsDelete: false)
        )
        _missingTracksService = StateObject(
            wrappedValue: MissingTracksService(
                rootDirectory: SeratoLibraryLocator.rootDirectory(for: libraryDirectory),
                databaseFileURL: library.databaseFile
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(crateHierarchy: crateHierarchy, smartCrateHierarchy: smartCrateHierarchy)
                .environmentObject(libraryService)
                .environmentObject(hiddenCrateStore)
                .environmentObject(missingTracksService)
        }
    }
}
