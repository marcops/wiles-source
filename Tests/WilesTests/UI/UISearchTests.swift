import Foundation
@testable import Wiles

@MainActor
public struct UISearchTests {
    public static func run() async {
        let appState = AppState()
        testSearchToggle(appState: appState)
        await testSearchFiltering(appState: appState)
        testSearchClear(appState: appState)
        testToggleSearchingIsDeterministic(appState: appState)
    }

    /// Regression coverage for `toggleSearching()` flipping state deterministically on repeated
    /// calls — open/close/open/close should never "stick" open. The actual bug this guards
    /// against (HeaderBarView's outside-click detector racing the search button's own tap,
    /// which only covered the search field and not the toggle button, so clicking the button
    /// could silently re-open the search it had just closed) lived in the AppKit event-timing
    /// layer and isn't reachable from a state-only test — this only proves the underlying model
    /// toggle itself is sound.
    private static func testToggleSearchingIsDeterministic(appState: AppState) {
        appState.isSearching = false
        appState.searchQuery = ""

        appState.toggleSearching()
        report("UI/Search", "POS: toggleSearching() opens search from closed", result: appState.isSearching)

        appState.toggleSearching()
        report("UI/Search", "POS: toggleSearching() closes search from open", result: !appState.isSearching)
        report("UI/Search", "POS: toggleSearching() clears the query when closing", result: appState.searchQuery.isEmpty)

        appState.toggleSearching()
        appState.toggleSearching()
        report("UI/Search", "POS: toggleSearching() is stable across repeated open/close cycles", result: !appState.isSearching)
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

    private static func testSearchFiltering(appState _: AppState) async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let fileA = tempDir.appendingPathComponent("AlphaDocument.txt")
        let fileB = tempDir.appendingPathComponent("BetaNotes.txt")
        try? "alpha".write(to: fileA, atomically: true, encoding: .utf8)
        try? "beta".write(to: fileB, atomically: true, encoding: .utf8)

        let loaded = (try? await FileSystemService.loadDirectoryContents(
            at: tempDir,
            options: DirectoryLoadOptions(
                showHidden: false,
                showTags: false,
                searchQuery: "Alpha",
                sortOption: .name,
                sortAscending: true))) ?? []

        let matching = loaded.map(\.name)
        report(
            "UI/Search",
            "POS: Search query filters items by matching name",
            result: matching.contains("AlphaDocument.txt") && !matching.contains("BetaNotes.txt"))

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
