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
        await testPrepareForSmartFolderRunTriggersSearch()
        await testPrepareForSmartFolderRunClearsStalePendingSelection()
        testPrepareForSmartFolderRunSuppressesFocusOnlyWhenSearchWasClosed()
        await testNormalSearchQueryEditKeepsSidebarHighlight()
        await testRunSmartFolderAppliesResultsToFileSystemItems()
        await testRunSmartFolderNavigatesToScopeAndUsesSearchEngine()
        await testRunSmartFolderWithSlowVolumeScopeDoesNotBlockSynchronously()
        await testRunSmartFolderWithSlowVolumeScopeDefersUntilNavigationCompletes()
        await testRunSmartFolderDoesNotPrepareWhenNavigationIsSupersededByACompetingCall()
        testToggleTagFilter()
    }

    /// HH-409: `runSmartFolder` used to call `FileManager.default.fileExists(atPath:)` directly on
    /// `@MainActor` for ANY `scopePath`, including a `/Volumes/…` one — which can block for seconds
    /// on a stalled/unreachable network share. A `/Volumes/…` scope must now take the same
    /// off-main path every other slow-volume navigation does, so `runSmartFolder` itself returns
    /// (near-)instantly regardless of whether the path is actually reachable.
    private static func testRunSmartFolderWithSlowVolumeScopeDoesNotBlockSynchronously() async {
        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        let folder = SmartFolder(
            name: "Remote", searchQuery: "x", scopePath: "/Volumes/NonexistentTestShare-\(UUID().uuidString)")

        let start = ContinuousClock.now
        appState.runSmartFolder(folder, windowUIState: windowUIState)
        let elapsed = start.duration(to: .now)

        report(
            "AppState",
            "POS (HH-409): runSmartFolder returns immediately even for a /Volumes/ scope (no synchronous fileExists on @MainActor)",
            result: elapsed < .milliseconds(200))
    }

    /// MM-098: for a `/Volumes/…` scope, `navigateTo` alone doesn't guarantee the navigation has
    /// landed by the time it returns (it resolves asynchronously). `runSmartFolder` must defer
    /// preparing/running the query until `navigateToAwaitingCompletion` actually resolves, instead of
    /// applying it synchronously and racing the navigation's own later completion (which used to
    /// reset the state just prepared via `resetViewStateForNavigation`).
    private static func testRunSmartFolderWithSlowVolumeScopeDefersUntilNavigationCompletes() async {
        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        let folder = SmartFolder(
            name: "Remote", searchQuery: "needle", scopePath: "/Volumes/NonexistentTestShare-\(UUID().uuidString)")

        appState.runSmartFolder(folder, windowUIState: windowUIState)

        report(
            "AppState",
            "POS (MM-098): preparing the smart folder run is deferred, not applied synchronously, for a /Volumes/ scope",
            result: appState.smartFolder.activeFolderID == nil)

        var resolved = false
        for _ in 0 ..< 30 {
            if appState.smartFolder.activeFolderID == folder.id {
                resolved = true
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        report(
            "AppState",
            "POS (MM-098): the smart folder run is eventually prepared once the async navigation resolves",
            result: resolved)
    }

    /// MB-202 (round 2): `navigateToAwaitingCompletion` can unblock two ways — it actually landed, or
    /// its slow-volume check was cancelled by a DIFFERENT, later navigation racing this one (HH-398).
    /// `runSmartFolder` must not prepare/run the query in the second case, since `navigation.currentURL`
    /// is then wherever the competing navigation left it, not this folder's scope.
    private static func testRunSmartFolderDoesNotPrepareWhenNavigationIsSupersededByACompetingCall() async {
        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        let localDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: localDir) }
        let folder = SmartFolder(
            name: "Remote", searchQuery: "needle", scopePath: "/Volumes/NonexistentTestShare-\(UUID().uuidString)")

        appState.runSmartFolder(folder, windowUIState: windowUIState)
        // Supersede it immediately with a fast, local navigation — this cancels the smart folder's
        // still-pending slow-volume check (HH-398) before it ever calls completeNavigation.
        appState.navigateTo(localDir)

        // Give the (now-cancelled) smart-folder Task every chance to run its guard and bail.
        try? await Task.sleep(nanoseconds: 300_000_000)

        report(
            "AppState",
            "NEG (MB-202): a smart folder run superseded by a competing navigation never prepares (activeFolderID stays nil)",
            result: appState.smartFolder.activeFolderID == nil)
        report(
            "AppState",
            "POS (MB-202): navigation.currentURL reflects the competing (winning) navigation, not the superseded smart folder's scope",
            result: appState.navigation.currentURL.standardizedFileURL.path == localDir.standardizedFileURL.path)
    }

    /// A saved smart folder navigates to its `scopePath` and runs its query through the standard
    /// search engine (same as typing in the header field) — keeping the sidebar highlight and the
    /// non-editable name pill.
    private static func testRunSmartFolderNavigatesToScopeAndUsesSearchEngine() async {
        let appState = AppState()
        let scope = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: scope, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scope) }
        let match = scope.appendingPathComponent("quarterly-report.txt")
        let noMatch = scope.appendingPathComponent("holiday-photo.jpg")
        try? "x".write(to: match, atomically: true, encoding: .utf8)
        try? "x".write(to: noMatch, atomically: true, encoding: .utf8)
        appState.navigation.currentURL = FileManager.default.homeDirectoryForCurrentUser
        let windowUIState = WindowUIState(preferences: appState.preferences)
        let folder = SmartFolder(name: "Reports", searchQuery: "report", scopePath: scope.path)

        appState.runSmartFolder(folder, windowUIState: windowUIState)

        report(
            "AppState", "POS: runSmartFolder navigates to the folder's scopePath",
            result: appState.navigation.currentURL.standardizedFileURL.path == scope.standardizedFileURL.path)
        report(
            "AppState", "POS: runSmartFolder keeps the sidebar highlight and shows the name pill",
            result: appState.smartFolder.activeFolderID == folder.id
                && appState.selection.isSearching && !windowUIState.isEditingSearch)

        var attempts = 0
        while !appState.fileSystem.items.contains(where: { $0.url.lastPathComponent == "quarterly-report.txt" }), attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        report(
            "AppState",
            "POS: runSmartFolder's query is applied by the search engine (match present, non-match filtered out)",
            result: appState.fileSystem.items.contains { $0.url.lastPathComponent == "quarterly-report.txt" }
                && !appState.fileSystem.items.contains { $0.url.lastPathComponent == "holiday-photo.jpg" })
    }

    /// Sidebar tag row: activating a tag turns on search with the lone `tag:` token; activating it
    /// again clears it; and switching to a tag from an active smart folder drops the folder's query
    /// instead of appending the tag onto it.
    private static func testToggleTagFilter() {
        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)

        appState.toggleTagFilter("Red", windowUIState: windowUIState)
        report(
            "AppState", "POS: toggleTagFilter turns on search with just the tag token",
            result: appState.selection.isSearching
                && appState.selection.searchQuery == "tag:Red" && !windowUIState.isEditingSearch)

        appState.toggleTagFilter("Red", windowUIState: windowUIState)
        report(
            "AppState", "POS: toggleTagFilter on the active tag clears it and exits search",
            result: !appState.selection.isSearching && appState.selection.searchQuery.isEmpty)

        appState.smartFolder.activeFolderID = UUID()
        appState.selection.setSearchQuerySilently("pdf")
        appState.selection.isSearching = true
        appState.toggleTagFilter("Blue", windowUIState: windowUIState)
        report(
            "AppState",
            "NEG: toggleTagFilter from a smart folder does not carry its query into the tag filter",
            result: appState.selection.searchQuery == "tag:Blue" && appState.smartFolder.activeFolderID == nil)
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

        UserDefaults.standard.removeObject(forKey: DefaultsKey.smartFolders.rawValue)
        let appState = AppState()
        let folder = SmartFolder(name: "My Folder", searchQuery: "report", scopePath: "/tmp")

        appState.addSmartFolder(folder)
        report(
            "AppState",
            "POS: addSmartFolder() appends the folder to smartFolders",
            result: appState.preferences.smartFolders.count == 1 && appState.preferences.smartFolders.first?.id == folder.id)

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report("AppState", "POS: addSmartFolder() persists the folder via SmartFolderService", result: persisted.contains { $0.id == folder.id })

        let other = SmartFolder(name: "Other", searchQuery: "x", scopePath: "/tmp")
        report(
            "AppState",
            "NEG: addSmartFolder() does not add an unrelated folder that was never added",
            result: !appState.preferences.smartFolders.contains { $0.id == other.id })
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

        let keep = SmartFolder(name: "Keep", searchQuery: "a", scopePath: "/tmp")
        let removeTarget = SmartFolder(name: "Remove", searchQuery: "b", scopePath: "/tmp")
        try? SmartFolderService.saveSmartFolders([keep, removeTarget])
        let appState = AppState()

        appState.removeSmartFolder(removeTarget)
        report(
            "AppState",
            "POS: removeSmartFolder() removes only the matching folder by id",
            result: appState.preferences.smartFolders.count == 1 && appState.preferences.smartFolders.first?.id == keep.id)

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report(
            "AppState",
            "POS: removeSmartFolder() persists the updated list without the removed folder",
            result: !persisted.contains { $0.id == removeTarget.id })

        appState.removeSmartFolder(removeTarget)
        report(
            "AppState",
            "NEG: removeSmartFolder() is a no-op when the folder is already absent",
            result: appState.preferences.smartFolders.count == 1 && appState.preferences.smartFolders.first?.id == keep.id)
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

        let folder = SmartFolder(name: "Old Name", searchQuery: "kind:image", scopePath: "/tmp")
        let other = SmartFolder(name: "Untouched", searchQuery: "kind:pdf", scopePath: "/tmp")
        try? SmartFolderService.saveSmartFolders([folder, other])
        let appState = AppState()

        appState.renameSmartFolder(folder, to: "New Name")
        report(
            "AppState",
            "POS: renameSmartFolder() updates the name in place, keeping the same id",
            result: appState.preferences.smartFolders.first { $0.id == folder.id }?.name == "New Name")
        report(
            "AppState",
            "NEG: renameSmartFolder() does not touch an unrelated folder",
            result: appState.preferences.smartFolders.first { $0.id == other.id }?.name == "Untouched")

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report(
            "AppState",
            "POS: renameSmartFolder() persists the new name via SmartFolderService",
            result: persisted.first { $0.id == folder.id }?.name == "New Name")

        appState.renameSmartFolder(folder, to: "   ")
        report(
            "AppState",
            "NEG: renameSmartFolder() with an all-whitespace name is a no-op, leaving the previous name untouched",
            result: appState.preferences.smartFolders.first { $0.id == folder.id }?.name == "New Name")
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

        let folder = SmartFolder(name: "My JPGs", searchQuery: "kind:image jpg", scopePath: "/tmp")
        let other = SmartFolder(name: "Untouched", searchQuery: "kind:pdf", scopePath: "/tmp")
        try? SmartFolderService.saveSmartFolders([folder, other])
        let appState = AppState()

        appState.updateSmartFolderQuery(folder, to: "kind:image jpeg")
        report(
            "AppState",
            "POS: updateSmartFolderQuery() updates the searchQuery in place, keeping the same id",
            result: appState.preferences.smartFolders.first { $0.id == folder.id }?.searchQuery == "kind:image jpeg")
        report(
            "AppState", "NEG: updateSmartFolderQuery() does not touch an unrelated folder",
            result: appState.preferences.smartFolders.first { $0.id == other.id }?.searchQuery == "kind:pdf")

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

    /// `prepareForSmartFolderRun` sets `searchQuery` *silently* (no `didSet` refresh) — it's only
    /// ever called by `runSmartFolder`, which runs the actual Spotlight query right after; the
    /// normal debounced directory refresh would just be wasted work racing those results.
    private static func testPrepareForSmartFolderRunTriggersSearch() async {
        let appState = AppState()
        appState.selection.selectedURLs = [URL(fileURLWithPath: "/tmp/previously-selected.txt")]
        appState.fileSystem.refreshTask?.cancel()
        appState.fileSystem.refreshTask = nil

        let folder = SmartFolder(name: "My JPGs", searchQuery: "kind:image", scopePath: "/tmp")
        appState.prepareForSmartFolderRun(folder)

        report("AppState", "POS: prepareForSmartFolderRun sets searchQuery to the folder's query", result: appState.selection.searchQuery == folder.searchQuery)
        report("AppState", "POS: prepareForSmartFolderRun turns on isSearching", result: appState.selection.isSearching)
        report("AppState", "NEG: prepareForSmartFolderRun clears any prior file selection", result: appState.selection.selectedURLs.isEmpty)
        // Silent: it must NOT spawn a directory refresh on its own.
        try? await Task.sleep(nanoseconds: 400_000_000)
        report(
            "AppState",
            "NEG: prepareForSmartFolderRun does not spawn a directory refresh (runSmartFolder runs the Spotlight query instead)",
            result: appState.fileSystem.refreshTask == nil)
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
        appState.selection.selectedURLs = [URL(fileURLWithPath: "/tmp/my-jpg-inside-the-smart-folder.jpg")]

        let folder = SmartFolder(name: "My JPGs", searchQuery: "kind:image", scopePath: "/tmp")
        appState.prepareForSmartFolderRun(folder)
        report("AppState", "POS: prepareForSmartFolderRun clears a stale pendingSelectionURL", result: appState.selection.pendingSelectionURL == nil)

        // Editing the search text exits smart-folder mode and triggers a real reload of the current
        // directory — this must not resurrect the stale pending selection.
        appState.selection.searchQuery = "stale"
        await appState.fileSystem.refreshTask?.value
        report(
            "AppState",
            "NEG: editing search text after a smart folder run does not resurrect the stale pending selection",
            result: !appState.selection.selectedURLs.contains(staleFile))
    }

    /// Regression: running a smart folder while the search bar wasn't already visible makes it
    /// newly appear, which used to auto-focus it — stealing keyboard focus right as the user was
    /// about to click a result, so their first click just resigned that focus instead of reaching
    /// the item underneath (classic AppKit click-eating). `prepareForSmartFolderRun` must ask the
    /// next search-field appearance to skip its auto-focus.
    private static func testPrepareForSmartFolderRunSuppressesFocusOnlyWhenSearchWasClosed() {
        let appStateFromClosed = AppState()
        appStateFromClosed.selection.isSearching = false
        appStateFromClosed.prepareForSmartFolderRun(SmartFolder(name: "A", searchQuery: "kind:image", scopePath: "/tmp"))
        report(
            "AppState",
            "POS: prepareForSmartFolderRun suppresses the next search-field auto-focus when search was closed",
            result: appStateFromClosed.smartFolder.suppressNextSearchFocus)

        let appStateAlreadyOpen = AppState()
        appStateAlreadyOpen.selection.isSearching = true
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
    private static func testNormalSearchQueryEditKeepsSidebarHighlight() async {
        let appState = AppState()
        let folder = SmartFolder(name: "My JPGs", searchQuery: "kind:image", scopePath: "/tmp")
        appState.prepareForSmartFolderRun(folder)
        appState.fileSystem.refreshTask?.cancel()
        appState.fileSystem.refreshTask = nil

        appState.selection.searchQuery = "a brand new search"

        report(
            "AppState",
            "POS: a normal searchQuery edit does NOT clear smartFolder.activeFolderID (sidebar highlight stays on the smart folder)",
            result: appState.smartFolder.activeFolderID == folder.id)
        await report(
            "AppState",
            "POS: a normal searchQuery edit triggers a real refresh (spawns a task after the search debounce)",
            result: spawnsRefreshTask(appState))
    }

    /// The search-query `didSet` now debounces before spawning the refresh task, so poll for it
    /// instead of checking synchronously.
    private static func spawnsRefreshTask(_ appState: AppState) async -> Bool {
        for _ in 0 ..< 40 {
            if appState.fileSystem.refreshTask != nil {
                return true
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        return false
    }

    /// `runSmartFolder` navigates to `scopePath` and runs the query through `refreshCurrentDirectory`
    /// (the standard search engine), which replaces `fileSystem.items` with the results. Proving the
    /// stale pre-run item is cleared once the async refresh lands.
    private static func testRunSmartFolderAppliesResultsToFileSystemItems() async {
        let appState = AppState()
        let stale = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("stale-\(UUID().uuidString).txt")
        appState.fileSystem.items = [FileItem.load(url: stale)]
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folder = SmartFolder(name: "Test", searchQuery: "Desktop", scopePath: home.path)
        let windowUIState = WindowUIState(preferences: appState.preferences)

        appState.runSmartFolder(folder, windowUIState: windowUIState)
        report("AppState", "POS: runSmartFolder sets the search query to the folder's query", result: appState.selection.searchQuery == folder.searchQuery)

        var attempts = 0
        while appState.fileSystem.items.contains(where: { $0.url == stale }), attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        report(
            "AppState",
            "POS: runSmartFolder replaces fileSystem.items with the search results (stale item is gone)",
            result: !appState.fileSystem.items.contains { $0.url == stale })
    }

    // `persistSmartFolders`'s `catch` branch (ErrorReporter.report + showError) is unreachable from
    // AppState: it only calls the public, non-throwing-encoder `SmartFolderService.saveSmartFolders(_:)`,
    // which always encodes with a real `JSONEncoder` — `SmartFolder`'s fields (String/UUID/etc.) can't
    // actually fail to encode. `SmartFolderService`'s own doc comment on its test-only throwing-encoder
    // overload confirms this: "there's no real-world way to trigger this otherwise." Left uncovered per
    // WILES_RULES.md's "disproportionate cost" exception rather than adding a fake injectable seam here.

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
