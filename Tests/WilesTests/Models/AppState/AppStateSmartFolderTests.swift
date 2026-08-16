import Foundation
@testable import Wiles

/// Split out of `AppStateCoreTests.swift` to keep that file under the `file_length`/
/// `type_body_length` SwiftLint limits — covers `AppState`'s smart-folder CRUD and
/// `prepareForSmartFolderRun` behavior (rule 16).
@MainActor
public struct AppStateSmartFolderTests {
    public static func run() async {
        testAddSmartFolder()
        testRemoveSmartFolder()
        testRenameSmartFolder()
        testUpdateSmartFolderQuery()
        testSearchScopeID()
        testPrepareForSmartFolderRunTriggersSearch()
        await testPrepareForSmartFolderRunClearsStalePendingSelection()
        testPrepareForSmartFolderRunSuppressesFocusOnlyWhenSearchWasClosed()
        testNormalSearchQueryEditKeepsSidebarHighlight()
    }

    private static func testAddSmartFolder() {
        let priorDefaultsData = UserDefaults.standard.data(forKey: DefaultsKey.smartFolders.rawValue)
        defer {
            if let priorDefaultsData {
                UserDefaults.standard.set(priorDefaultsData, forKey: DefaultsKey.smartFolders.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: DefaultsKey.smartFolders.rawValue)
            }
        }

        let appState = AppState()
        appState.smartFolders = []
        let folder = SmartFolder(name: "My Folder", searchQuery: "report", scopePath: "/tmp")

        appState.addSmartFolder(folder)
        report(
            "AppState",
            "POS: addSmartFolder() appends the folder to smartFolders",
            result: appState.smartFolders.count == 1 && appState.smartFolders.first?.id == folder.id)

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report("AppState", "POS: addSmartFolder() persists the folder via SmartFolderService", result: persisted.contains { $0.id == folder.id })

        let other = SmartFolder(name: "Other", searchQuery: "x", scopePath: "/tmp")
        report(
            "AppState",
            "NEG: addSmartFolder() does not add an unrelated folder that was never added",
            result: appState.smartFolders.contains { $0.id == other.id } == false)
    }

    private static func testRemoveSmartFolder() {
        let priorDefaultsData = UserDefaults.standard.data(forKey: DefaultsKey.smartFolders.rawValue)
        defer {
            if let priorDefaultsData {
                UserDefaults.standard.set(priorDefaultsData, forKey: DefaultsKey.smartFolders.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: DefaultsKey.smartFolders.rawValue)
            }
        }

        let appState = AppState()
        let keep = SmartFolder(name: "Keep", searchQuery: "a", scopePath: "/tmp")
        let removeTarget = SmartFolder(name: "Remove", searchQuery: "b", scopePath: "/tmp")
        appState.smartFolders = [keep, removeTarget]

        appState.removeSmartFolder(removeTarget)
        report(
            "AppState",
            "POS: removeSmartFolder() removes only the matching folder by id",
            result: appState.smartFolders.count == 1 && appState.smartFolders.first?.id == keep.id)

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report(
            "AppState",
            "POS: removeSmartFolder() persists the updated list without the removed folder",
            result: persisted.contains { $0.id == removeTarget.id } == false)

        appState.removeSmartFolder(removeTarget)
        report(
            "AppState",
            "NEG: removeSmartFolder() is a no-op when the folder is already absent",
            result: appState.smartFolders.count == 1 && appState.smartFolders.first?.id == keep.id)
    }

    private static func testRenameSmartFolder() {
        let priorDefaultsData = UserDefaults.standard.data(forKey: DefaultsKey.smartFolders.rawValue)
        defer {
            if let priorDefaultsData {
                UserDefaults.standard.set(priorDefaultsData, forKey: DefaultsKey.smartFolders.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: DefaultsKey.smartFolders.rawValue)
            }
        }

        let appState = AppState()
        let folder = SmartFolder(name: "Old Name", searchQuery: "kind:image", scopePath: "/tmp")
        let other = SmartFolder(name: "Untouched", searchQuery: "kind:pdf", scopePath: "/tmp")
        appState.smartFolders = [folder, other]

        appState.renameSmartFolder(folder, to: "New Name")
        report(
            "AppState",
            "POS: renameSmartFolder() updates the name in place, keeping the same id",
            result: appState.smartFolders.first { $0.id == folder.id }?.name == "New Name")
        report(
            "AppState",
            "NEG: renameSmartFolder() does not touch an unrelated folder",
            result: appState.smartFolders.first { $0.id == other.id }?.name == "Untouched")

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report(
            "AppState",
            "POS: renameSmartFolder() persists the new name via SmartFolderService",
            result: persisted.first { $0.id == folder.id }?.name == "New Name")

        appState.renameSmartFolder(folder, to: "   ")
        report(
            "AppState",
            "NEG: renameSmartFolder() with an all-whitespace name is a no-op, leaving the previous name untouched",
            result: appState.smartFolders.first { $0.id == folder.id }?.name == "New Name")
    }

    private static func testUpdateSmartFolderQuery() {
        let priorDefaultsData = UserDefaults.standard.data(forKey: DefaultsKey.smartFolders.rawValue)
        defer {
            if let priorDefaultsData {
                UserDefaults.standard.set(priorDefaultsData, forKey: DefaultsKey.smartFolders.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: DefaultsKey.smartFolders.rawValue)
            }
        }

        let appState = AppState()
        let folder = SmartFolder(name: "My JPGs", searchQuery: "kind:image jpg", scopePath: "/tmp")
        let other = SmartFolder(name: "Untouched", searchQuery: "kind:pdf", scopePath: "/tmp")
        appState.smartFolders = [folder, other]

        appState.updateSmartFolderQuery(folder, to: "kind:image jpeg")
        report(
            "AppState",
            "POS: updateSmartFolderQuery() updates the searchQuery in place, keeping the same id",
            result: appState.smartFolders.first { $0.id == folder.id }?.searchQuery == "kind:image jpeg")
        report(
            "AppState", "NEG: updateSmartFolderQuery() does not touch an unrelated folder",
            result: appState.smartFolders.first { $0.id == other.id }?.searchQuery == "kind:pdf")

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report(
            "AppState", "POS: updateSmartFolderQuery() persists the new query via SmartFolderService",
            result: persisted.first { $0.id == folder.id }?.searchQuery == "kind:image jpeg")
    }

    private static func testSearchScopeID() {
        report(
            "AppState", "POS: SearchScope.id returns the case's rawValue for every case",
            result: SearchScope.name.id == "name" && SearchScope.content.id == "content" && SearchScope.both.id == "both")
    }

    /// Regression: `prepareForSmartFolderRun` used to assign `searchQuery` through a suppressed
    /// path that deliberately skipped `refreshCurrentDirectory()`, to avoid racing the smart
    /// folder's own cross-directory Spotlight query. That also meant clicking a smart folder never
    /// actually triggered a search — the same call typing in the search field makes. It must assign
    /// `searchQuery` normally so its `didSet` fires the real search.
    private static func testPrepareForSmartFolderRunTriggersSearch() {
        let appState = AppState()
        appState.selectedURLs = [URL(fileURLWithPath: "/tmp/previously-selected.txt")]
        appState.refreshTask?.cancel()
        appState.refreshTask = nil

        let folder = SmartFolder(name: "My JPGs", searchQuery: "kind:image", scopePath: "/tmp")
        appState.prepareForSmartFolderRun(folder)

        report("AppState", "POS: prepareForSmartFolderRun sets searchQuery to the folder's query", result: appState.searchQuery == folder.searchQuery)
        report("AppState", "POS: prepareForSmartFolderRun turns on isSearching", result: appState.isSearching)
        report("AppState", "NEG: prepareForSmartFolderRun clears any prior file selection", result: appState.selectedURLs.isEmpty)
        report(
            "AppState",
            "POS: prepareForSmartFolderRun actually triggers a search (spawns a refresh task), same as typing a query",
            result: appState.refreshTask != nil)
        report(
            "AppState", "POS: prepareForSmartFolderRun sets smartFolder.activeFolderID to the folder's id",
            result: appState.smartFolder.activeFolderID == folder.id)
    }

    /// Regression: a stale `selection.pendingSelectionURL` (left over from an earlier "go up a
    /// folder" navigation) must be cleared before the smart folder's own search runs — otherwise
    /// it's still sitting there the moment that search's results load, and gets applied in a
    /// totally unrelated context, silently reinstating whatever was selected long before the smart
    /// folder ran instead of the item the user actually picked inside its results.
    private static func testPrepareForSmartFolderRunClearsStalePendingSelection() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let staleFile = dir.appendingPathComponent("stale_previous_selection.txt")
        try? "x".write(to: staleFile, atomically: true, encoding: .utf8)

        let appState = AppState()
        appState.navigation.currentURL = dir
        appState.selection.pendingSelectionURL = staleFile
        appState.selectedURLs = [URL(fileURLWithPath: "/tmp/my-jpg-inside-the-smart-folder.jpg")]

        let folder = SmartFolder(name: "My JPGs", searchQuery: "kind:image", scopePath: "/tmp")
        appState.prepareForSmartFolderRun(folder)
        report("AppState", "POS: prepareForSmartFolderRun clears a stale pendingSelectionURL", result: appState.selection.pendingSelectionURL == nil)

        // Editing the search text exits smart-folder mode and triggers a real reload of the current
        // directory — this must not resurrect the stale pending selection.
        appState.searchQuery = "stale"
        await appState.refreshTask?.value
        report(
            "AppState",
            "NEG: editing search text after a smart folder run does not resurrect the stale pending selection",
            result: !appState.selectedURLs.contains(staleFile))
    }

    /// Regression: running a smart folder while the search bar wasn't already visible makes it
    /// newly appear, which used to auto-focus it — stealing keyboard focus right as the user was
    /// about to click a result, so their first click just resigned that focus instead of reaching
    /// the item underneath (classic AppKit click-eating). `prepareForSmartFolderRun` must ask the
    /// next search-field appearance to skip its auto-focus.
    private static func testPrepareForSmartFolderRunSuppressesFocusOnlyWhenSearchWasClosed() {
        let appStateFromClosed = AppState()
        appStateFromClosed.isSearching = false
        appStateFromClosed.prepareForSmartFolderRun(SmartFolder(name: "A", searchQuery: "kind:image", scopePath: "/tmp"))
        report(
            "AppState",
            "POS: prepareForSmartFolderRun suppresses the next search-field auto-focus when search was closed",
            result: appStateFromClosed.smartFolder.suppressNextSearchFocus)

        let appStateAlreadyOpen = AppState()
        appStateAlreadyOpen.isSearching = true
        appStateAlreadyOpen.prepareForSmartFolderRun(SmartFolder(name: "B", searchQuery: "kind:image", scopePath: "/tmp"))
        report(
            "AppState",
            "NEG: prepareForSmartFolderRun does not suppress focus when the search field was already open (no new appearance to steal focus)",
            result: !appStateAlreadyOpen.smartFolder.suppressNextSearchFocus)
    }

    /// A normal `searchQuery` edit — typing, clearing, a filter button — must NOT clear
    /// `activeFolderID`: that only drives the sidebar's active-row highlight, which should keep
    /// showing the smart folder as selected while you refine its query text — clearing it here made
    /// the sidebar jump back to whatever was selected before the smart folder ran the instant you
    /// edited the search box, which is a real regression a user caught.
    private static func testNormalSearchQueryEditKeepsSidebarHighlight() {
        let appState = AppState()
        let folder = SmartFolder(name: "My JPGs", searchQuery: "kind:image", scopePath: "/tmp")
        appState.prepareForSmartFolderRun(folder)
        appState.refreshTask?.cancel()
        appState.refreshTask = nil

        appState.searchQuery = "a brand new search"

        report(
            "AppState",
            "POS: a normal searchQuery edit does NOT clear smartFolder.activeFolderID (sidebar highlight stays on the smart folder)",
            result: appState.smartFolder.activeFolderID == folder.id)
        report(
            "AppState",
            "POS: a normal searchQuery edit triggers a real refresh (spawns a task)",
            result: appState.refreshTask != nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
