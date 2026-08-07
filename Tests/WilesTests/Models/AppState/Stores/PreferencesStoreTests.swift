@testable import Wiles
import Foundation

@MainActor
public struct PreferencesStoreTests {
    public static func run() {
        let store = PreferencesStore()
        report("Store/PreferencesStore", "POS: iconSize is within valid bounds", result: store.iconSize >= IconSizeToken.minSize && store.iconSize <= IconSizeToken.maxSize)

        let initialHidden = store.showHiddenFiles
        defer { store.showHiddenFiles = initialHidden }

        store.showHiddenFiles.toggle()
        report("Store/PreferencesStore", "POS: showHiddenFiles toggles correctly", result: store.showHiddenFiles != initialHidden)

        testExpandedTreePathsCapsInsertionsAt500()
        testExpandedTreePathsTruncatesOnLoadWhenSavedSetExceedsCap()
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

        let overCapInOneShot = Set((0..<600).map { "/tmp/wiles-test-onshot-\($0)-\(UUID().uuidString)" })
        store.expandedTreePaths = overCapInOneShot
        report(
            "Store/PreferencesStore",
            "NEG: assigning a 600-entry set to expandedTreePaths in one shot is rejected (reverts to the prior value) since it exceeds the 500 cap",
            result: store.expandedTreePaths.isEmpty
        )

        for i in 0..<510 {
            var updated = store.expandedTreePaths
            updated.insert("/tmp/wiles-test-incremental-\(i)")
            store.expandedTreePaths = updated
        }
        report(
            "Store/PreferencesStore",
            "POS: inserting one path at a time past the cap stops growing expandedTreePaths once it reaches 500",
            result: store.expandedTreePaths.count == 500
        )

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

        let oversizedSaved = (0..<600).map { "/tmp/wiles-test-saved-\($0)" }
        UserDefaults.standard.set(oversizedSaved, forKey: key)

        let store = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: loading a saved expandedTreePaths array of 600 entries truncates to the 500 cap on init",
            result: store.expandedTreePaths.count == 500
        )
        report(
            "Store/PreferencesStore",
            "NEG: loading an oversized saved set does not silently drop to empty",
            result: !store.expandedTreePaths.isEmpty
        )

        // The freshly-constructed store's didSet just scheduled a debounced save of the truncated
        // 500-entry set; overwrite with the real prior value so that pending write, whenever it fires,
        // can't clobber real user data (see doc comment on the sibling test above).
        store.expandedTreePaths = Set(priorArray ?? [])
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
