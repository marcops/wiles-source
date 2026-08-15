import Foundation
@testable import Wiles

@MainActor
public struct PreferencesStoreTests {
    public static func run() {
        let store = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: iconSize is within valid bounds",
            result: store.iconSize >= IconSizeToken.minSize && store.iconSize <= IconSizeToken.maxSize)

        let initialHidden = store.showHiddenFiles
        defer { store.showHiddenFiles = initialHidden }

        store.showHiddenFiles.toggle()
        report("Store/PreferencesStore", "POS: showHiddenFiles toggles correctly", result: store.showHiddenFiles != initialHidden)

        testExpandedTreePathsCapsInsertionsAt500()
        testExpandedTreePathsTruncatesOnLoadWhenSavedSetExceedsCap()
        testShowDirectoryTreePersistsAcrossStoreInstances()
        testIconSizeLoadsSavedValueWithinBounds()
        testFavoriteURLsFallsBackToDefaultsWhenNoneSaved()
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
            result: store.iconSize == validSize)
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
            result: store.favoriteURLs == expectedCandidates)
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
        let defaultValue = store.showDirectoryTree
        store.showDirectoryTree = !defaultValue

        let reloaded = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: showDirectoryTree persists to UserDefaults and is restored by a freshly-constructed PreferencesStore",
            result: reloaded.showDirectoryTree == !defaultValue)

        // Flip back and restore the real prior value so a real user's setting isn't clobbered.
        store.showDirectoryTree = defaultValue
    }

    // MARK: - expandedTreePaths cap (500 entries)

    /// `PreferencesStore.expandedTreePaths`'s `didSet` reverts to `oldValue` (dropping the update
    /// entirely) whenever the new value would exceed `maxExpandedTreePaths` (500). This mutates the
    /// real `UserDefaults.standard` key (`PreferencesStore` has no injectable suite), so per rule 17
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
        store.expandedTreePaths = []

        let overCapInOneShot = Set((0 ..< 600).map { "/tmp/wiles-test-onshot-\($0)-\(UUID().uuidString)" })
        store.expandedTreePaths = overCapInOneShot
        report(
            "Store/PreferencesStore",
            "NEG: assigning a 600-entry set to expandedTreePaths in one shot is rejected (reverts to the prior value) since it exceeds the 500 cap",
            result: store.expandedTreePaths.isEmpty)

        for i in 0 ..< 510 {
            var updated = store.expandedTreePaths
            updated.insert("/tmp/wiles-test-incremental-\(i)")
            store.expandedTreePaths = updated
        }
        report(
            "Store/PreferencesStore",
            "POS: inserting one path at a time past the cap stops growing expandedTreePaths once it reaches 500",
            result: store.expandedTreePaths.count == 500)

        // Restore in-memory + reschedule the pending debounced save with the real prior data (see doc comment above).
        store.expandedTreePaths = Set(priorArray ?? [])
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
            result: store.expandedTreePaths.count == 500)
        report(
            "Store/PreferencesStore",
            "NEG: loading an oversized saved set does not silently drop to empty",
            result: !store.expandedTreePaths.isEmpty)

        // The freshly-constructed store's didSet just scheduled a debounced save of the truncated
        // 500-entry set; overwrite with the real prior value so that pending write, whenever it fires,
        // can't clobber real user data (see doc comment on the sibling test above).
        store.expandedTreePaths = Set(priorArray ?? [])
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
