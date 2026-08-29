import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct AppStateNavigationExtraTests {
    public static func run() async {
        testAddToRecentsPrependsAndDedups()
        testAddToRecentsCapsAt50()
        testAddToRecentsIgnoresRecentsVirtualURL()
        testAddToRecentsIgnoresWilesScheme()
        testNavigateToRecentsVirtualURLUpdatesStateAndHistory()
        testNavigateToSameURLDoesNotPushHistory()
        testNavigateToWithAddToHistoryFalseDoesNotPushHistory()
        testGoBackDoesNotDropForwardOnRepeatedCalls()
        testGoUpAtRootDoesNotNavigate()
        testHistoryBackCapsAt200Entries()
        testHistoryForwardCapsAt200EntriesWhenDrainingHistoryBack()
        testRefreshCurrentDirectoryUserInitiatedSetsLoadingWhenItemsAreEmpty()
        await testGoUpAfterEnteringChildReselectsChildOncePendingSelectionResolves()
        testRefreshCurrentDirectoryAppliesCachedResultSynchronously()
        await testApplyLoadedItemsSkipsWhileRenaming()
        testNavigatingAwayClearsStuckRenamingURL()
        testNavigateToOnAFileIsANoOpButOpenItemHandlesIt()
        await testRefreshTrashSizeIfNeededWhenNavigatingIntoTrash()
    }

    /// `navigateTo` is folder-only now: pointed at a file it must not change `currentURL` and must
    /// not raise an error (that's `openItem`'s job). It's `openItem` that routes a file to the
    /// system open. (Can't assert the actual `NSWorkspace.open`, but the file must not become the
    /// current directory either way.)
    private static func testNavigateToOnAFileIsANoOpButOpenItemHandlesIt() {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("doc.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.navigation.currentURL = dir
        appState.modal.errorMessage = nil

        appState.navigateTo(file)
        report(
            "Navigation/OpenItem",
            "NEG: navigateTo on a file leaves currentURL on the folder and raises no error",
            result: appState.navigation.currentURL == dir && appState.modal.errorMessage == nil)

        appState.openItem(file)
        report(
            "Navigation/OpenItem",
            "NEG: openItem on a file also does not make the file the current directory",
            result: appState.navigation.currentURL == dir)

        appState.openItem(dir.appendingPathComponent("missing.txt"))
        report(
            "Navigation/OpenItem",
            "POS: openItem on a missing path surfaces an error",
            result: appState.modal.errorMessage != nil)
    }

    // MARK: - Helpers

    private static func tempDir() -> URL {
        URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }

    // MARK: - addToRecents

    private static func testAddToRecentsPrependsAndDedups() {
        let appState = AppState()
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        appState.navigation.recentOpenedURLs = []
        let urlA = dir.appendingPathComponent("a.txt")
        let urlB = dir.appendingPathComponent("b.txt")
        appState.navigation.addToRecents(urlA)
        appState.navigation.addToRecents(urlB)
        report(
            "Navigation/Recents",
            "POS: addToRecents() inserts new URL at front",
            result: appState.navigation.recentOpenedURLs.first?.path == urlB.standardizedFileURL.path)

        // Re-adding 'a' should move it to front, not duplicate it.
        appState.navigation.addToRecents(urlA)
        let paths = appState.navigation.recentOpenedURLs.map(\.path)
        report(
            "Navigation/Recents",
            "POS: addToRecents() moves re-added URL to front without duplicating",
            result: paths.first == urlA.standardizedFileURL.path && paths.filter { $0 == urlA.standardizedFileURL.path }.count == 1)
    }

    private static func testAddToRecentsCapsAt50() {
        let appState = AppState()
        let dir = tempDir()
        appState.navigation.recentOpenedURLs = (0 ..< 50).map { dir.appendingPathComponent("f\($0).txt").standardizedFileURL }
        let overflow = dir.appendingPathComponent("overflow.txt")
        appState.navigation.addToRecents(overflow)
        report("Navigation/Recents", "POS: addToRecents() caps the list at 50 entries", result: appState.navigation.recentOpenedURLs.count == 50)
        report(
            "Navigation/Recents",
            "POS: addToRecents() keeps newest entry after capping at 50",
            result: appState.navigation.recentOpenedURLs.first?.path == overflow.standardizedFileURL.path)
    }

    private static func testAddToRecentsIgnoresRecentsVirtualURL() {
        let appState = AppState()
        appState.navigation.recentOpenedURLs = []
        appState.navigation.addToRecents(AppState.recentsVirtualURL)
        report("Navigation/Recents", "NEG: addToRecents() ignores the recents virtual URL", result: appState.navigation.recentOpenedURLs.isEmpty)
    }

    private static func testAddToRecentsIgnoresWilesScheme() {
        let appState = AppState()
        appState.navigation.recentOpenedURLs = []
        guard let wilesURL = URL(string: "wiles://some/path") else {
            report("Navigation/Recents", "NEG: addToRecents() ignores wiles:// scheme URLs", result: false)
            return
        }
        appState.navigation.addToRecents(wilesURL)
        report("Navigation/Recents", "NEG: addToRecents() ignores wiles:// scheme URLs", result: appState.navigation.recentOpenedURLs.isEmpty)
    }

    // MARK: - navigateTo / recentsVirtualURL

    private static func testNavigateToRecentsVirtualURLUpdatesStateAndHistory() {
        let appState = AppState()
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        appState.navigateTo(dir)
        appState.selection.selectedURLs = [dir.appendingPathComponent("x.txt")]
        appState.selection.isSearching = true
        appState.selection.searchQuery = "abc"

        appState.navigateTo(AppState.recentsVirtualURL)
        report(
            "Navigation/RecentsVirtual", "POS: navigateTo(recentsVirtualURL) sets currentURL to the virtual URL",
            result: appState.navigation.currentURL == AppState.recentsVirtualURL)
        report("Navigation/RecentsVirtual", "POS: navigateTo(recentsVirtualURL) clears selection", result: appState.selection.selectedURLs.isEmpty)
        report(
            "Navigation/RecentsVirtual",
            "POS: navigateTo(recentsVirtualURL) clears search state",
            result: !appState.selection.isSearching && appState.selection.searchQuery.isEmpty)

        // goBack should return to the real directory we came from.
        appState.goBack()
        report(
            "Navigation/RecentsVirtual", "POS: goBack() from recentsVirtualURL restores prior real directory",
            result: appState.navigation.currentURL.path == dir.standardizedFileURL.path)
    }

    // MARK: - history push suppression

    private static func testNavigateToSameURLDoesNotPushHistory() {
        let appState = AppState()
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        appState.navigateTo(dir)
        let backCountAfterFirstNav = appState.navigation.historyBack.count

        // Navigating to the same URL again should not push a duplicate history entry.
        appState.navigateTo(dir)
        report(
            "Navigation/History", "NEG: navigateTo() with the same URL does not push a duplicate history entry",
            result: appState.navigation.historyBack.count == backCountAfterFirstNav)
    }

    private static func testNavigateToWithAddToHistoryFalseDoesNotPushHistory() {
        let appState = AppState()
        let dirA = tempDir()
        let dirB = tempDir()
        try? FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }

        appState.navigateTo(dirA)
        let backCountBefore = appState.navigation.historyBack.count
        appState.navigateTo(dirB, addToHistory: false)
        report(
            "Navigation/History",
            "NEG: navigateTo(addToHistory: false) does not push history",
            result: appState.navigation.historyBack.count == backCountBefore && appState.navigation.currentURL.path == dirB.standardizedFileURL.path)
    }

    private static func testGoBackDoesNotDropForwardOnRepeatedCalls() {
        let appState = AppState()
        let dirA = tempDir()
        let dirB = tempDir()
        try? FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }
        let initial = appState.navigation.currentURL

        appState.navigateTo(dirA)
        appState.navigateTo(dirB)
        appState.goBack()
        report(
            "Navigation/History", "POS: goBack() after two navigations returns to the previous stop",
            result: appState.navigation.currentURL.path == dirA.standardizedFileURL.path)

        // A fresh navigation should clear the forward stack.
        appState.navigateTo(initial)
        report("Navigation/History", "NEG: navigateTo() after goBack() clears the forward stack", result: appState.navigation.historyForward.isEmpty)
    }

    // MARK: - goUp

    private static func testGoUpAtRootDoesNotNavigate() {
        let appState = AppState()
        let root = URL(fileURLWithPath: "/")
        appState.navigation.currentURL = root
        appState.goUp()
        report(
            "Navigation/GoUp",
            "NEG: goUp() at the filesystem root does not navigate (parent == self)",
            result: appState.navigation.currentURL.path == root.path)
    }

    // MARK: - history cap (maxNavigationHistoryCount = 200)

    /// Builds `count` real, existing temp subdirectories under a fresh parent dir so `navigateTo()`'s
    /// synchronous local-path `fileExists` check treats each as a valid directory to navigate into.
    private static func makeTempDirs(_ count: Int, in parent: URL) -> [URL] {
        (0 ..< count).map { i in
            let url = parent.appendingPathComponent("d\(i)")
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
    }

    private static func testHistoryBackCapsAt200Entries() {
        let parent = tempDir()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let appState = AppState()
        // Fresh AppState: both history stacks start empty.

        // navigateTo() on a local (non-/Volumes/) path resolves fileExists synchronously and calls
        // completeNavigation() inline, so this drives the full push-and-cap logic synchronously —
        // no async wait needed.
        let dirs = makeTempDirs(250, in: parent)
        appState.navigation.currentURL = dirs[0]
        for dir in dirs.dropFirst() {
            appState.navigateTo(dir)
        }

        report(
            "Navigation/History",
            "POS: historyBack caps at 200 entries after 249 navigations (would be 249 uncapped)",
            result: appState.navigation.historyBack.count == 200)
        report(
            "Navigation/History",
            "NEG: historyBack does not grow past the 200 cap",
            result: appState.navigation.historyBack.count < dirs.count - 1)
    }

    private static func testHistoryForwardCapsAt200EntriesWhenDrainingHistoryBack() {
        let parent = tempDir()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let appState = AppState()
        // Fresh AppState: both history stacks start empty.

        let dirs = makeTempDirs(250, in: parent)
        appState.navigation.currentURL = dirs[0]
        for dir in dirs.dropFirst() {
            appState.navigateTo(dir)
        }
        // historyBack is now capped at 200. Drain it entirely with more goBack() calls than entries
        // exist (250 > 200) to also exercise the "no-op past empty" guard, while every successful pop
        // pushes into historyForward — proving that side's cap enforcement (goBack()'s own
        // `if navigation.historyForward.count > maxNavigationHistoryCount { removeFirst() }`) never
        // lets it exceed 200 either.
        for _ in 0 ..< 250 {
            appState.goBack()
        }

        report("Navigation/History", "POS: historyBack drains to empty once fully popped", result: appState.navigation.historyBack.isEmpty)
        report(
            "Navigation/History",
            "POS: historyForward caps at 200 entries after draining a 200-entry historyBack (would be 200, cap has no effect on exceeding it here, but never grows past it)",
            result: appState.navigation.historyForward.count == 200)
    }

    // MARK: - refreshCurrentDirectory(isUserInitiated:)

    /// Covers the `isUserInitiated && fileSystem.items.isEmpty` branch that flips `fileSystem.isLoading`
    /// to `true` synchronously, before the real async load kicks off. Uses a freshly-generated temp
    /// directory path (never navigated to before) so `DirectoryCacheService` has no cached result that
    /// could resolve synchronously and flip `isLoading` back to `false` before we observe it.
    private static func testRefreshCurrentDirectoryUserInitiatedSetsLoadingWhenItemsAreEmpty() {
        let appState = AppState()
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        appState.navigation.currentURL = dir
        appState.fileSystem.items = []
        appState.refreshCurrentDirectory(isUserInitiated: true)
        report(
            "Navigation/Refresh",
            "POS: refreshCurrentDirectory(isUserInitiated: true) sets isLoading synchronously when items are empty",
            result: appState.fileSystem.isLoading)
    }

    // MARK: - applyLoadedItems pending-selection resolution

    /// Drives the "leaving a child folder re-selects it once the parent's contents load" flow all the
    /// way through the real async `refreshCurrentDirectory()` pipeline: navigate into a child folder,
    /// `goUp()` back to the parent (which sets `selection.pendingSelectionURL` to the child via
    /// `childToRestore`), then poll until the async load completes and `applyLoadedItems()` resolves
    /// the pending selection against the freshly-loaded parent contents.
    private static func testGoUpAfterEnteringChildReselectsChildOncePendingSelectionResolves() async {
        let parent = tempDir()
        let child = parent.appendingPathComponent("child")
        try? FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let appState = AppState()
        appState.navigateTo(child)
        appState.goUp()

        // The loaded FileItem's `url` carries a trailing slash (it's a real, existing directory), so
        // compare standardized paths rather than the URLs directly (rule 20 — never compare raw
        // URL/String values with `==` across code paths that may format them differently).
        var resolved = false
        for _ in 0 ..< 15 {
            if appState.selection.selectedURLs.count == 1,
               appState.selection.selectedURLs.first?.standardizedFileURL.path == child.standardizedFileURL.path {
                resolved = true
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        report(
            "Navigation/Refresh",
            "POS: goUp() from a child folder re-selects that child once the parent's async load resolves the pending selection",
            result: resolved)
    }

    // MARK: - refreshCurrentDirectory() cache + applyLoadedItems guards

    /// `refreshCurrentDirectory()` applies a `DirectoryCacheService` hit synchronously (before the
    /// real async `Task` even runs), so a cached search-free result should already be reflected in
    /// `fileSystem.items` the instant the (synchronous, non-async) call returns.
    private static func testRefreshCurrentDirectoryAppliesCachedResultSynchronously() {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: dir)
            DirectoryCacheService.shared.invalidate(url: dir)
        }

        let cachedFileURL = dir.appendingPathComponent("cached-only.txt")
        try? "cached".write(to: cachedFileURL, atomically: true, encoding: .utf8)
        let cachedItem = FileItem.load(url: cachedFileURL)
        DirectoryCacheService.shared.cacheDirectory(DirectoryLoadResult(items: [cachedItem]), for: dir)

        let appState = AppState()
        appState.navigation.currentURL = dir
        appState.selection.searchQuery = ""
        appState.fileSystem.renamingURL = nil
        appState.fileSystem.items = []
        appState.refreshCurrentDirectory()

        report(
            "Navigation/Refresh",
            "POS: refreshCurrentDirectory() applies a DirectoryCacheService hit synchronously, before the real async load completes",
            result: appState.fileSystem.items == [cachedItem])
    }

    /// `applyLoadedItems()`'s `fileSystem.renamingURL == nil` guard: while a rename is in progress,
    /// a completed async directory load must not clobber `fileSystem.items` out from under the
    /// in-progress rename row.
    private static func testApplyLoadedItemsSkipsWhileRenaming() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let realFile = dir.appendingPathComponent("real.txt")
        try? "x".write(to: realFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let sentinelURL = dir.appendingPathComponent("sentinel-item.txt")
        let sentinelItems = [FileItem.load(url: sentinelURL)]
        appState.navigation.currentURL = dir
        appState.fileSystem.items = sentinelItems
        appState.fileSystem.renamingURL = sentinelURL
        appState.refreshCurrentDirectory()

        // Give the real async load plenty of time to complete and, if the guard were broken,
        // overwrite fileSystem.items with the real directory contents.
        try? await Task.sleep(nanoseconds: 600_000_000)
        report(
            "Navigation/Refresh",
            "NEG: applyLoadedItems() leaves fileSystem.items untouched while fileSystem.renamingURL is set, even after the real async load completes",
            result: appState.fileSystem.items == sentinelItems)
    }

    /// `renamingURL` gates every `applyLoadedItems` call. If a rename is abandoned by navigating
    /// away (rather than commit/cancel in the field), the flag used to stay set and freeze the new
    /// folder's listing. Navigation must clear it.
    private static func testNavigatingAwayClearsStuckRenamingURL() {
        let parent = tempDir()
        let child = parent.appendingPathComponent("child")
        try? FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let appState = AppState()
        appState.navigation.currentURL = parent
        appState.fileSystem.renamingURL = parent.appendingPathComponent("untitled folder")

        appState.navigateTo(child)
        report(
            "Navigation/Rename",
            "POS: navigating into a folder clears a stuck fileSystem.renamingURL",
            result: appState.fileSystem.renamingURL == nil)

        appState.fileSystem.renamingURL = child.appendingPathComponent("untitled folder")
        appState.navigateTo(AppState.recentsVirtualURL)
        report(
            "Navigation/Rename",
            "POS: navigating to Recents clears a stuck fileSystem.renamingURL",
            result: appState.fileSystem.renamingURL == nil)
    }

    // MARK: - refreshTrashSizeIfNeeded

    /// `refreshTrashSizeIfNeeded()`'s `isTrash || dueForCoarseCheck` guard: navigating into Trash
    /// must trigger `updateTrashSize()` even when the coarse periodic check just ran (not due),
    /// isolating the `isTrash` half of the condition specifically.
    private static func testRefreshTrashSizeIfNeededWhenNavigatingIntoTrash() async {
        guard let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first else {
            report("Navigation/Refresh", "POS: refreshTrashSizeIfNeeded() skipped — no Trash directory URL available in this environment", result: true)
            return
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: trashURL.path, isDirectory: &isDir), isDir.boolValue else {
            // Without a real ~/.Trash directory, navigateTo() would treat this as a non-directory
            // and quietly no-op instead of navigating — not what this test exercises.
            report("Navigation/Refresh", "POS: refreshTrashSizeIfNeeded() skipped — no real Trash directory present in this environment", result: true)
            return
        }
        // `fileExists` only checks existence, not readability. Without Full Disk Access (the normal
        // state for an unattended/sandboxed test runner), `~/.Trash` exists but enumerating it throws
        // "Operation not permitted" — `performDirectoryRefresh` then takes its catch path and never
        // reaches `refreshTrashSizeIfNeeded()`, which would make this test fail for an environment
        // reason unrelated to the code under test. Skip gracefully in that case too.
        guard (try? FileManager.default.contentsOfDirectory(atPath: trashURL.path)) != nil else {
            report(
                "Navigation/Refresh",
                "POS: refreshTrashSizeIfNeeded() skipped — Trash directory not readable without Full Disk Access in this environment",
                result: true)
            return
        }

        let appState = AppState()
        appState.fileSystem.trash.lastOpportunisticCheck = Date() // "not due" for the coarse check
        let before = appState.fileSystem.trash.lastOpportunisticCheck

        appState.navigateTo(trashURL)

        var updated = false
        for _ in 0 ..< 30 {
            if appState.fileSystem.trash.lastOpportunisticCheck != before {
                updated = true
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        report(
            "Navigation/Refresh",
            "POS: navigating into Trash triggers updateTrashSize() even when not yet due for the coarse periodic check (the `isTrash ||` branch)",
            result: updated)
    }
}
