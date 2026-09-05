import AppKit
import Foundation
@testable import Wiles

/// `AppState` directory-refresh behavior: the synchronous `DirectoryCacheService` fast path, the
/// `renamingURL` guard that protects an in-progress rename from a late async load, and the
/// navigate-into-Trash branch of `refreshTrashSizeIfNeeded`. Split out of
/// `AppStateNavigationExtraTests` to stay under the `file_length` limit.
@MainActor
public struct AppStateDirectoryRefreshTests {
    public static func run() async {
        testRefreshCurrentDirectoryAppliesCachedResultSynchronously()
        await testApplyLoadedItemsSkipsWhileRenaming()
        testNavigatingAwayClearsStuckRenamingURL()
        await testRefreshTrashSizeIfNeededWhenNavigatingIntoTrash()
        await testDirectoryListingCompletesUnderContinuousExternalWritePressure()
    }

    private static func tempDir() -> URL {
        URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }

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

    /// A monitor-triggered refresh used to unconditionally cancel-and-restart the in-flight load
    /// (`AppState.startDirectoryMonitoring`'s callback); a folder large enough that one full listing
    /// takes longer than the monitor's own debounce floor never got a chance to finish while
    /// external writes kept arriving. Timing-based by nature (this bug IS a race) — reproduces it
    /// with a real folder and real continuous writes rather than a mock.
    private static func testDirectoryListingCompletesUnderContinuousExternalWritePressure() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for i in 0 ..< 4000 {
            FileManager.default.createFile(atPath: dir.appendingPathComponent("f\(i).txt").path, contents: nil)
        }

        let appState = AppState()
        appState.navigateTo(dir)

        let churnTask = Task.detached {
            let decoy = dir.appendingPathComponent("churn.txt")
            while !Task.isCancelled {
                try? "x".write(to: decoy, atomically: true, encoding: .utf8)
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        defer { churnTask.cancel() }

        // Checks the observable outcome (items populated), not the internal `isRefreshing` flag —
        // this assertion has to hold whether or not that flag exists, to actually prove the bug.
        var settled = false
        for _ in 0 ..< 60 {
            if !appState.fileSystem.items.isEmpty {
                settled = true
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        report(
            "Navigation/Refresh",
            "POS: a folder's listing eventually completes even under continuous external write pressure, instead of restarting forever",
            result: settled)
    }
}
