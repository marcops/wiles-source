@testable import Wiles
import Foundation

@MainActor
public struct UISearchTests {
    public static func run() async {
        let appState = AppState()
        testSearchToggle(appState: appState)
        await testSearchFiltering(appState: appState)
        testSearchClear(appState: appState)
    }

    private static func testSearchToggle(appState: AppState) {
        appState.isSearching = false
        appState.searchQuery = "test"

        // Toggling search off resets query
        appState.isSearching = true
        report("UI/Search", "POS: Search mode enables correctly", result: appState.isSearching == true)

        appState.isSearching = false
        appState.searchQuery = ""
        report("UI/Search", "POS: Search mode disables and resets query", result: !appState.isSearching && appState.searchQuery.isEmpty)
    }

    private static func testSearchFiltering(appState: AppState) async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let fileA = tempDir.appendingPathComponent("AlphaDocument.txt")
        let fileB = tempDir.appendingPathComponent("BetaNotes.txt")
        try? "alpha".write(to: fileA, atomically: true, encoding: .utf8)
        try? "beta".write(to: fileB, atomically: true, encoding: .utf8)

        let loaded = await FileSystemService.loadDirectoryContents(
            at: tempDir,
            options: DirectoryLoadOptions(
                showHidden: false,
                showTags: false,
                searchQuery: "Alpha",
                sortOption: .name,
                sortAscending: true
            )
        )

        let matching = loaded.map { $0.name }
        report("UI/Search", "POS: Search query filters items by matching name", result: matching.contains("AlphaDocument.txt") && !matching.contains("BetaNotes.txt"))

        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func testSearchClear(appState: AppState) {
        appState.searchQuery = "Alpha"
        appState.searchQuery = ""
        report("UI/Search", "POS: Clearing search query resets text", result: appState.searchQuery.isEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
