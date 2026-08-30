import Foundation
@testable import Wiles

@MainActor
public struct PreferencesStoreTests {
    public static func run() {
        let store = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: iconSize is within valid bounds",
            result: store.view.iconSize >= IconSizeToken.minSize && store.view.iconSize <= IconSizeToken.maxSize)

        let initialHidden = store.view.showHiddenFiles
        defer { store.view.showHiddenFiles = initialHidden }

        store.view.showHiddenFiles.toggle()
        report("Store/PreferencesStore", "POS: showHiddenFiles toggles correctly", result: store.view.showHiddenFiles != initialHidden)

        testExpandedTreePathsCapsInsertionsAt500()
        testPerFolderViewModesEvictsInsteadOfRevertingAtCap()
        testExpandedTreePathsTruncatesOnLoadWhenSavedSetExceedsCap()
        testShowDirectoryTreePersistsAcrossStoreInstances()
        testIconSizeLoadsSavedValueWithinBounds()
        testFavoriteURLsFallsBackToDefaultsWhenNoneSaved()
        testFavoriteURLsLoadsSavedArrayOptimisticallyAcceptingVolumesPaths()
        testResolvedFavoritePathsStaysInSyncWithFavoriteURLs()
        testStandardizedFavoritePathsIsTheUnresolvedSet()
    }

    /// `standardizedFavoritePaths` — the no-`stat` fast path for `AppState.isFavorite`: plain
    /// standardized paths, symlinks left unresolved.
    private static func testStandardizedFavoritePathsIsTheUnresolvedSet() {
        let key = DefaultsKey.favoriteURLs.rawValue
        let prior = UserDefaults.standard.stringArray(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
        }
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let real = dir.appendingPathComponent("Real")
        try? FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let link = dir.appendingPathComponent("Link")
        try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        let store = PreferencesStore()
        store.favorites.favoriteURLs = [real, link]
        report(
            "Store/PreferencesStore",
            "POS: standardizedFavoritePaths is the plain (unresolved) standardized path set",
            result: store.favorites.standardizedFavoritePaths == Set([real, link].map(\.standardizedFileURL.path)))
    }

    // MARK: - resolvedFavoritePaths (M25)

    /// `resolvedFavoritePaths` is recomputed in `favoriteURLs`'s `didSet` as the symlink-resolved,
    /// standardized path set — the O(1) lookup backing `AppState.isFavorite`. It must track every
    /// mutation (assign / append / remove / reorder) and resolve symlinks. Mutates the real
    /// `DefaultsKey.favoriteURLs`, so per rule 17 it's snapshotted and restored in `defer`.
    private static func testResolvedFavoritePathsStaysInSyncWithFavoriteURLs() {
        let key = DefaultsKey.favoriteURLs.rawValue
        let priorArray = UserDefaults.standard.stringArray(forKey: key)
        defer {
            if let priorArray {
                UserDefaults.standard.set(priorArray, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let real = dir.appendingPathComponent("RealFolder")
        let other = dir.appendingPathComponent("Other")
        try? FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let link = dir.appendingPathComponent("LinkToReal")
        try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        func resolved(_ urls: [URL]) -> Set<String> {
            Set(urls.map { $0.resolvingSymlinksInPath().standardizedFileURL.path })
        }

        let store = PreferencesStore()

        store.favorites.favoriteURLs = []
        report(
            "Store/PreferencesStore",
            "POS: resolvedFavoritePaths is empty when favoriteURLs is empty",
            result: store.favorites.resolvedFavoritePaths.isEmpty)

        store.favorites.favoriteURLs = [real, other]
        report(
            "Store/PreferencesStore",
            "POS: resolvedFavoritePaths equals the symlink-resolved set of favoriteURLs after assignment",
            result: store.favorites.resolvedFavoritePaths == resolved([real, other]))

        store.favorites.favoriteURLs.append(link)
        report(
            "Store/PreferencesStore",
            "POS: appending a symlink to favoriteURLs recomputes resolvedFavoritePaths with the symlink's real target path",
            result: store.favorites.resolvedFavoritePaths == resolved([real, other, link])
                && store.favorites.resolvedFavoritePaths.contains(real.resolvingSymlinksInPath().standardizedFileURL.path))

        store.favorites.favoriteURLs.swapAt(0, 2)
        report(
            "Store/PreferencesStore",
            "POS: reordering favoriteURLs keeps resolvedFavoritePaths correct (order-independent set)",
            result: store.favorites.resolvedFavoritePaths == resolved([real, other, link]))

        store.favorites.favoriteURLs.removeAll { $0 == other }
        report(
            "Store/PreferencesStore",
            "POS: removing from favoriteURLs recomputes resolvedFavoritePaths",
            result: store.favorites.resolvedFavoritePaths == resolved([real, link])
                && !store.favorites.resolvedFavoritePaths.contains(other.resolvingSymlinksInPath().standardizedFileURL.path))
    }

    // MARK: - favoriteURLs load-from-saved-array branch

    /// `loadFavoriteURLs`'s `if let savedFavs` branch (the sibling of the already-covered
    /// fallback-to-defaults `else`) filters each saved path through `existsOptimistically`: a real
    /// existing path passes via `FileManager.fileExists`, a `/Volumes/...` path is accepted
    /// optimistically regardless of existence (`isLikelySlowVolume`, to avoid a synchronous stall
    /// against a sleeping network share), and a genuinely-missing non-`/Volumes/` path is dropped.
    /// Checked synchronously right after `init` — before the `Task { [weak self] in await
    /// validateSlowVolumeFavorites() }` it also spawns has a chance to run — so this only exercises
    /// the optimistic-load path, not the later async correction (which would need a real/simulated
    /// mount to deterministically resolve either way). That task captures `self` weakly and this
    /// `store` is a purely local variable nothing else retains, so it deallocates at the end of this
    /// function and the pending task becomes a safe no-op rather than writing stale data back to
    /// `UserDefaults` later. This mutates the real `UserDefaults.standard` key, so per rule 17 we
    /// snapshot and restore in `defer`.
    private static func testFavoriteURLsLoadsSavedArrayOptimisticallyAcceptingVolumesPaths() {
        let key = DefaultsKey.favoriteURLs.rawValue
        let priorArray = UserDefaults.standard.stringArray(forKey: key)
        defer {
            if let priorArray {
                UserDefaults.standard.set(priorArray, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let realExistingPath = FileManager.default.homeDirectoryForCurrentUser.path
        let missingVolumesPath = "/Volumes/DefinitelyNotMounted-\(UUID().uuidString)"
        let missingRegularPath = URL(fileURLWithPath: testTemporaryDirectory())
            .appendingPathComponent("definitely-missing-\(UUID().uuidString)").path

        UserDefaults.standard.set([realExistingPath, missingVolumesPath, missingRegularPath], forKey: key)
        let store = PreferencesStore()
        let paths = store.favorites.favoriteURLs.map(\.path)

        report(
            "Store/PreferencesStore",
            "POS: loadFavoriteURLs keeps a real existing saved path",
            result: paths.contains(realExistingPath))
        report(
            "Store/PreferencesStore",
            "POS: loadFavoriteURLs optimistically accepts a /Volumes/ path even though it doesn't exist",
            result: paths.contains(missingVolumesPath))
        report(
            "Store/PreferencesStore",
            "NEG: loadFavoriteURLs drops a genuinely-missing non-/Volumes/ saved path",
            result: !paths.contains(missingRegularPath))
    }

    // MARK: - iconSize load-from-UserDefaults bounds check

    /// `loadSearchAndDisplayPreferences` only applies a saved `iconSize` from `UserDefaults` when it
    /// falls within `IconSizeToken.minSize...maxSize` (line 247's `if` guard). Every other test in
    /// this suite constructs `PreferencesStore()` against whatever `wiles_iconSize` happens to be
    /// real `UserDefaults.standard` state, which never deterministically exercises the true branch.
    /// This mutates the real `UserDefaults.standard` key (`PreferencesStore` has no injectable
    /// suite), so per rule 17 we snapshot and restore the real value in `defer`.
    private static func testIconSizeLoadsSavedValueWithinBounds() {
        let key = DefaultsKey.iconSize.rawValue
        let priorValue = UserDefaults.standard.object(forKey: key) as? Double
        defer {
            if let priorValue {
                UserDefaults.standard.set(priorValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let validSize = IconSizeToken.minSize + IconSizeToken.step
        UserDefaults.standard.set(validSize, forKey: key)
        let store = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: a saved iconSize within IconSizeToken bounds is restored on init",
            result: store.view.iconSize == validSize)
    }

    // MARK: - favoriteURLs default fallback when nothing saved

    /// `loadFavoriteURLs`'s `else` branch (lines 258-263) seeds `favoriteURLs` with the user's real
    /// Desktop/Documents/Downloads directories, filtered to only those that actually exist, whenever
    /// `UserDefaults` has no saved `wiles_favoriteURLs` array yet. This mutates the real
    /// `UserDefaults.standard` key, so per rule 17 we snapshot and restore the real value in `defer`.
    private static func testFavoriteURLsFallsBackToDefaultsWhenNoneSaved() {
        let key = DefaultsKey.favoriteURLs.rawValue
        let priorArray = UserDefaults.standard.stringArray(forKey: key)
        defer {
            if let priorArray {
                UserDefaults.standard.set(priorArray, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        let store = PreferencesStore()
        let expectedCandidates = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
        report(
            "Store/PreferencesStore",
            "POS: favoriteURLs falls back to the existing Desktop/Documents/Downloads defaults when no saved array exists",
            result: store.favorites.favoriteURLs == expectedCandidates)
    }

    // MARK: - showDirectoryTree persistence

    /// `showDirectoryTree` (the independent sidebar toggle that replaced the old mutually-exclusive
    /// `SidebarMode` picker — see UI_TEST_BACKLOG.md) writes through `didSet` to
    /// `DefaultsKey.showDirectoryTree` and is restored on `init` via `loadBool`, exactly like its
    /// sibling `show*` sidebar-visibility booleans. This mutates the real `UserDefaults.standard`
    /// key (`PreferencesStore` has no injectable suite), so per rule 17 we snapshot and restore the
    /// real value in `defer`.
    private static func testShowDirectoryTreePersistsAcrossStoreInstances() {
        let key = DefaultsKey.showDirectoryTree.rawValue
        let priorValue = UserDefaults.standard.object(forKey: key) as? Bool
        defer {
            if let priorValue {
                UserDefaults.standard.set(priorValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let store = PreferencesStore()
        let defaultValue = store.sidebar.showDirectoryTree
        store.sidebar.showDirectoryTree = !defaultValue

        let reloaded = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: showDirectoryTree persists to UserDefaults and is restored by a freshly-constructed PreferencesStore",
            result: reloaded.sidebar.showDirectoryTree == !defaultValue)

        // Flip back and restore the real prior value so a real user's setting isn't clobbered.
        store.sidebar.showDirectoryTree = defaultValue
    }

    // MARK: - expandedTreePaths cap (500 entries)

    /// `PreferencesStore.sidebar.expandedTreePaths`'s `didSet` evicts down to `maxExpandedTreePaths` (500)
    /// instead of reverting the whole assignment, so a disclosure triangle at the cap still opens.
    /// This mutates the real `UserDefaults.standard` key (`PreferencesStore` has no injectable suite), so per rule 17
    /// we snapshot and restore the real value in `defer`. Every successful assignment also reschedules
    /// a debounced 0.5s write of the *current* `expandedTreePaths`; ending with an assignment back to
    /// the true prior value ensures that debounced write — whenever it eventually fires — persists the
    /// real data rather than test data, even though the `defer` below fires synchronously well before it.
    private static func testExpandedTreePathsCapsInsertionsAt500() {
        let key = DefaultsKey.expandedTreePaths.rawValue
        let priorArray = UserDefaults.standard.stringArray(forKey: key)
        defer {
            if let priorArray {
                UserDefaults.standard.set(priorArray, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let store = PreferencesStore()
        store.sidebar.expandedTreePaths = []

        let overCapInOneShot = Set((0 ..< 600).map { "/tmp/wiles-test-onshot-\($0)-\(UUID().uuidString)" })
        store.sidebar.expandedTreePaths = overCapInOneShot
        report(
            "Store/PreferencesStore",
            "POS: assigning a 600-entry set to expandedTreePaths in one shot evicts down to the 500 cap instead of reverting",
            result: store.sidebar.expandedTreePaths.count == 500)

        for i in 0 ..< 510 {
            var updated = store.sidebar.expandedTreePaths
            updated.insert("/tmp/wiles-test-incremental-\(i)")
            store.sidebar.expandedTreePaths = updated
        }
        report(
            "Store/PreferencesStore",
            "POS: inserting one path at a time past the cap stops growing expandedTreePaths once it reaches 500",
            result: store.sidebar.expandedTreePaths.count == 500)

        // Restore in-memory + reschedule the pending debounced save with the real prior data (see doc comment above).
        store.sidebar.expandedTreePaths = Set(priorArray ?? [])
    }

    // MARK: - perFolderViewModes cap (500 entries) — H1 regression

    /// `PreferencesStore.view.perFolderViewModes`'s `didSet` must evict down to `maxPerFolderViewModes`
    /// (500) instead of reverting the whole assignment. The old code did `perFolderViewModes =
    /// oldValue; return`, so once a user had 500 per-folder view modes stored, every subsequent
    /// `setViewModeForFolder` silently no-op'd. Mutates the real `UserDefaults.standard` key, so
    /// per rule 17 the value is snapshotted and restored in `defer`.
    private static func testPerFolderViewModesEvictsInsteadOfRevertingAtCap() {
        let key = DefaultsKey.perFolderViewModes.rawValue
        let priorDict = UserDefaults.standard.dictionary(forKey: key) as? [String: String]
        defer {
            if let priorDict {
                UserDefaults.standard.set(priorDict, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let store = PreferencesStore()
        store.view.perFolderViewModes = [:]

        var overCap: [String: String] = [:]
        for i in 0 ..< 600 {
            overCap["/tmp/wiles-pfvm-oneshot-\(i)-\(UUID().uuidString)"] = "list"
        }
        store.view.perFolderViewModes = overCap
        report(
            "Store/PreferencesStore",
            "POS: assigning a 600-entry dictionary to perFolderViewModes evicts down to the 500 cap instead of reverting",
            result: store.view.perFolderViewModes.count == 500)

        // At the cap, a fresh per-folder change must take effect (old code reverted it away).
        let atCapCount = store.view.perFolderViewModes.count
        var withNewKey = store.view.perFolderViewModes
        let newKey = "/tmp/wiles-pfvm-latest-\(UUID().uuidString)"
        withNewKey[newKey] = "grid"
        store.view.perFolderViewModes = withNewKey
        report(
            "Store/PreferencesStore",
            "POS: setting a new folder's view mode at the cap keeps the new key and stays at 500",
            result: store.view.perFolderViewModes[newKey] == "grid" && store.view.perFolderViewModes.count == min(atCapCount, 500))

        store.view.perFolderViewModes = priorDict ?? [:]
    }

    // MARK: - expandedTreePaths truncate-on-load

    /// Loading a saved `expandedTreePaths` array larger than the cap must truncate to the first 500
    /// entries (`.prefix(maxExpandedTreePaths)`), not silently drop to an empty set.
    private static func testExpandedTreePathsTruncatesOnLoadWhenSavedSetExceedsCap() {
        let key = DefaultsKey.expandedTreePaths.rawValue
        let priorArray = UserDefaults.standard.stringArray(forKey: key)
        defer {
            if let priorArray {
                UserDefaults.standard.set(priorArray, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let oversizedSaved = (0 ..< 600).map { "/tmp/wiles-test-saved-\($0)" }
        UserDefaults.standard.set(oversizedSaved, forKey: key)

        let store = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: loading a saved expandedTreePaths array of 600 entries truncates to the 500 cap on init",
            result: store.sidebar.expandedTreePaths.count == 500)
        report(
            "Store/PreferencesStore",
            "NEG: loading an oversized saved set does not silently drop to empty",
            result: !store.sidebar.expandedTreePaths.isEmpty)

        // The freshly-constructed store's didSet just scheduled a debounced save of the truncated
        // 500-entry set; overwrite with the real prior value so that pending write, whenever it fires,
        // can't clobber real user data (see doc comment on the sibling test above).
        store.sidebar.expandedTreePaths = Set(priorArray ?? [])
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
