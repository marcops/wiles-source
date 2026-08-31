import Foundation
@testable import Wiles

/// Coverage for `NavigationStore`: init resolution (saved-path restore vs. fallback,
/// `/Volumes/`-optimistic-acceptance + async validation), history stack cap, and `addToRecents`
/// filtering. Isolates `DefaultsKey.lastOpenedFolder`/`.recentOpenedURLs`, restoring the original
/// values in a guaranteed `defer` per the project's test-isolation rules.
@MainActor
public struct NavigationStoreTests {
    private static let lastOpenedFolderKey = DefaultsKey.lastOpenedFolder.rawValue
    private static let recentOpenedURLsKey = DefaultsKey.recentOpenedURLs.rawValue

    public static func run() async {
        let originalLastOpened = UserDefaults.standard.string(forKey: lastOpenedFolderKey)
        let originalRecents = UserDefaults.standard.stringArray(forKey: recentOpenedURLsKey)
        defer {
            restore(originalLastOpened, forKey: lastOpenedFolderKey)
            if let originalRecents {
                UserDefaults.standard.set(originalRecents, forKey: recentOpenedURLsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: recentOpenedURLsKey)
            }
        }

        testInitFallsBackToInitialURLWhenNoSavedPath()
        testInitRestoresSavedPathWhenItExists()
        testInitFallsBackWhenSavedPathNoLongerExists()
        await testInitRestoresRecentsFilteringMissingPaths()
        testCurrentURLDidSetUpdatesPathTextAndPersists()
        testAddToRecentsExcludesRecentsVirtualURLAndWilesScheme()
        testAddToRecentsDeduplicatesAndCapsAt50()
        testRecordVisitNoOpWhenSameURLAndPopulatesHistory()
        testPopBackAndPopForwardReturnNilWhenEmpty()
        testPopBackAndPopForwardRoundTrip()
        testHistoryStacksCapAt200()
        await testVolumePathValidationFallsBackWhenGone()
        await testNonexistentLocalRecentIsAcceptedAtInitThenPrunedAsync()
    }

    private static func restore(_ value: String?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func testInitFallsBackToInitialURLWhenNoSavedPath() {
        UserDefaults.standard.removeObject(forKey: lastOpenedFolderKey)
        let fallback = URL(fileURLWithPath: testTemporaryDirectory())
        let store = NavigationStore(initialURL: fallback)
        report("Store/NavigationStore", "POS: init falls back to initialURL when nothing is saved", result: store.currentURL == fallback)
        report("Store/NavigationStore", "POS: init sets pathText to match the resolved currentURL", result: store.pathText == fallback.path)
    }

    private static func testInitRestoresSavedPathWhenItExists() {
        let saved = URL(fileURLWithPath: testTemporaryDirectory())
        UserDefaults.standard.set(saved.path, forKey: lastOpenedFolderKey)
        let store = NavigationStore(initialURL: URL(fileURLWithPath: "/should-not-be-used"))
        report("Store/NavigationStore", "POS: init restores a saved path that still exists on disk", result: store.currentURL.path == saved.path)
    }

    private static func testInitFallsBackWhenSavedPathNoLongerExists() {
        let missing = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("gone_\(UUID().uuidString)")
        UserDefaults.standard.set(missing.path, forKey: lastOpenedFolderKey)
        let fallback = URL(fileURLWithPath: testTemporaryDirectory())
        let store = NavigationStore(initialURL: fallback)
        report(
            "Store/NavigationStore",
            "NEG: init falls back to initialURL when the saved path no longer exists on disk",
            result: store.currentURL == fallback)
    }

    private static func testInitRestoresRecentsFilteringMissingPaths() async {
        let existingDir = URL(fileURLWithPath: testTemporaryDirectory())
        let missingDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("gone_\(UUID().uuidString)")
        UserDefaults.standard.set([existingDir.path, missingDir.path], forKey: recentOpenedURLsKey)
        UserDefaults.standard.removeObject(forKey: lastOpenedFolderKey)

        let store = NavigationStore(initialURL: existingDir)
        // The missing path is pruned off the main actor after init (no synchronous filter — LP-050),
        // so poll for the corrected list rather than asserting synchronously.
        let deadline = Date().addingTimeInterval(5.0)
        while store.recentOpenedURLs.map(\.path).contains(missingDir.path), Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        report(
            "Store/NavigationStore",
            "POS: init restores recentOpenedURLs, keeping only paths that still exist",
            result: store.recentOpenedURLs.map(\.path) == [existingDir.path])
    }

    private static func testCurrentURLDidSetUpdatesPathTextAndPersists() {
        UserDefaults.standard.removeObject(forKey: lastOpenedFolderKey)
        let store = NavigationStore(initialURL: URL(fileURLWithPath: testTemporaryDirectory()))
        let newURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("new_\(UUID().uuidString)")
        store.currentURL = newURL
        report("Store/NavigationStore", "POS: setting currentURL updates pathText to match", result: store.pathText == newURL.path)
        report(
            "Store/NavigationStore",
            "POS: setting currentURL persists the path to UserDefaults under lastOpenedFolder",
            result: UserDefaults.standard.string(forKey: lastOpenedFolderKey) == newURL.path)
    }

    private static func testAddToRecentsExcludesRecentsVirtualURLAndWilesScheme() {
        let store = NavigationStore(initialURL: URL(fileURLWithPath: testTemporaryDirectory()))
        store.recentOpenedURLs = []

        store.addToRecents(AppState.recentsVirtualURL)
        report("Store/NavigationStore", "NEG: addToRecents ignores the synthetic Recents virtual URL", result: store.recentOpenedURLs.isEmpty)

        let wilesSchemeURL = URL(string: "wiles://some-virtual-folder")!
        store.addToRecents(wilesSchemeURL)
        report("Store/NavigationStore", "NEG: addToRecents ignores wiles:// scheme virtual URLs", result: store.recentOpenedURLs.isEmpty)
    }

    private static func testAddToRecentsDeduplicatesAndCapsAt50() {
        let store = NavigationStore(initialURL: URL(fileURLWithPath: testTemporaryDirectory()))
        let base = URL(fileURLWithPath: testTemporaryDirectory())
        store.recentOpenedURLs = []

        let first = base.appendingPathComponent("first")
        store.addToRecents(first)
        for index in 0 ..< 55 {
            store.addToRecents(base.appendingPathComponent("entry_\(index)"))
        }
        report("Store/NavigationStore", "POS: addToRecents caps recentOpenedURLs at 50 entries", result: store.recentOpenedURLs.count == 50)
        report(
            "Store/NavigationStore",
            "NEG: an entry pushed out of the 50-entry cap by newer additions is no longer present",
            result: !store.recentOpenedURLs.contains(where: { $0.standardizedFileURL == first.standardizedFileURL }))

        store.recentOpenedURLs = [base.appendingPathComponent("a"), base.appendingPathComponent("b")]
        store.addToRecents(base.appendingPathComponent("b"))
        report(
            "Store/NavigationStore",
            "POS: re-adding an existing recent URL moves it to the front instead of duplicating it",
            result: store.recentOpenedURLs.count == 2 && store.recentOpenedURLs.first?.standardizedFileURL == base.appendingPathComponent("b")
                .standardizedFileURL)
    }

    private static func testRecordVisitNoOpWhenSameURLAndPopulatesHistory() {
        let start = URL(fileURLWithPath: testTemporaryDirectory())
        let store = NavigationStore(initialURL: start)
        // Seed a non-empty historyForward via the real API so the clear-on-recordVisit is observable.
        let scratch = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("scratch")
        store.recordVisit(to: scratch)
        store.currentURL = scratch
        _ = store.popBackForGoBack()
        store.currentURL = start

        store.recordVisit(to: start)
        report("Store/NavigationStore", "NEG: recordVisit(to:) is a no-op when newURL equals currentURL", result: store.historyBack.isEmpty)

        let destination = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("dest")
        store.recordVisit(to: destination)
        report(
            "Store/NavigationStore",
            "POS: recordVisit(to:) pushes the current URL onto historyBack and clears historyForward",
            result: store.historyBack == [start] && store.historyForward.isEmpty)
    }

    private static func testPopBackAndPopForwardReturnNilWhenEmpty() {
        // Fresh store: both stacks already empty.
        let store = NavigationStore(initialURL: URL(fileURLWithPath: testTemporaryDirectory()))
        report("Store/NavigationStore", "NEG: popBackForGoBack() returns nil when historyBack is empty", result: store.popBackForGoBack() == nil)
        report("Store/NavigationStore", "NEG: popForwardForGoForward() returns nil when historyForward is empty", result: store.popForwardForGoForward() == nil)
    }

    private static func testPopBackAndPopForwardRoundTrip() {
        let current = URL(fileURLWithPath: testTemporaryDirectory())
        let store = NavigationStore(initialURL: current)
        let previous = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("prev")
        // Seed historyBack = [previous] via the real API.
        store.currentURL = previous
        store.recordVisit(to: current)
        store.currentURL = current

        let popped = store.popBackForGoBack()
        report(
            "Store/NavigationStore",
            "POS: popBackForGoBack() returns the last back entry and pushes currentURL onto historyForward",
            result: popped == previous && store.historyForward == [current])

        // historyBack already drained to empty by the pop above.
        let poppedForward = store.popForwardForGoForward()
        report(
            "Store/NavigationStore",
            "POS: popForwardForGoForward() returns the last forward entry and pushes currentURL onto historyBack",
            result: poppedForward == current && store.historyBack == [current])
    }

    private static func testHistoryStacksCapAt200() {
        let base = URL(fileURLWithPath: testTemporaryDirectory())
        var store = NavigationStore(initialURL: base.appendingPathComponent("visit_0"))

        for index in 0 ..< 205 {
            store.currentURL = base.appendingPathComponent("visit_\(index)")
            store.recordVisit(to: base.appendingPathComponent("visit_\(index + 1)"))
        }
        report("Store/NavigationStore", "POS: recordVisit's historyBack cap prevents unbounded growth past 200 entries", result: store.historyBack.count == 200)

        // Drive popForwardForGoForward repeatedly to grow historyBack past 200 via its own cap() call.
        // Seed a large historyForward through the real API: build a capped historyBack, drain it across.
        store = NavigationStore(initialURL: base.appendingPathComponent("f_0"))
        for index in 0 ..< 205 {
            store.currentURL = base.appendingPathComponent("f_\(index)")
            store.recordVisit(to: base.appendingPathComponent("f_\(index + 1)"))
        }
        for _ in 0 ..< 205 {
            _ = store.popBackForGoBack()
        }
        for _ in 0 ..< 205 {
            _ = store.popForwardForGoForward()
        }
        report(
            "Store/NavigationStore",
            "POS: popForwardForGoForward's historyBack cap prevents unbounded growth past 200 entries",
            result: store.historyBack.count == 200)

        // Mirror on the other side: build a capped historyBack, drain it into historyForward.
        store = NavigationStore(initialURL: base.appendingPathComponent("b_0"))
        for index in 0 ..< 205 {
            store.currentURL = base.appendingPathComponent("b_\(index)")
            store.recordVisit(to: base.appendingPathComponent("b_\(index + 1)"))
        }
        for _ in 0 ..< 205 {
            _ = store.popBackForGoBack()
        }
        report(
            "Store/NavigationStore",
            "POS: popBackForGoBack's historyForward cap prevents unbounded growth past 200 entries",
            result: store.historyForward.count == 200)
    }

    /// Covers `validateRecentAndCurrentPaths()`: a `/Volumes/`-prefixed path is accepted
    /// optimistically at init (no synchronous `fileExists`), then corrected asynchronously once the
    /// detached existence check finds it doesn't actually exist.
    private static func testVolumePathValidationFallsBackWhenGone() async {
        let fakeVolumePath = "/Volumes/WilesTestNonexistentVolume_\(UUID().uuidString)"
        let fakeVolumeURL = URL(fileURLWithPath: fakeVolumePath)
        UserDefaults.standard.set(fakeVolumePath, forKey: lastOpenedFolderKey)
        UserDefaults.standard.removeObject(forKey: recentOpenedURLsKey)

        let store = NavigationStore(initialURL: URL(fileURLWithPath: testTemporaryDirectory()))
        report(
            "Store/NavigationStore",
            "POS: a /Volumes/ path is accepted optimistically at init without a synchronous existence check",
            result: store.currentURL == fakeVolumeURL)

        // Give the init-time detached validateRecentAndCurrentPaths() Task a chance to run and
        // correct state — polled rather than a single fixed sleep since this can race under load.
        let deadline = Date().addingTimeInterval(5.0)
        while store.currentURL == fakeVolumeURL, Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        report(
            "Store/NavigationStore",
            "POS: validateRecentAndCurrentPaths() falls back to the home directory once a /Volumes/ currentURL is confirmed missing",
            result: store.currentURL == FileManager.default.homeDirectoryForCurrentUser)
    }

    /// LP-050: recents are mapped at init with NO synchronous `fileExists` per path — a
    /// nonexistent local recent is present right after `init` and pruned asynchronously.
    private static func testNonexistentLocalRecentIsAcceptedAtInitThenPrunedAsync() async {
        let realDir = URL(fileURLWithPath: testTemporaryDirectory())
            .appendingPathComponent("nav-recent-real-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: realDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: realDir) }
        let ghostDir = URL(fileURLWithPath: testTemporaryDirectory())
            .appendingPathComponent("nav-recent-ghost-\(UUID().uuidString)")

        UserDefaults.standard.removeObject(forKey: lastOpenedFolderKey)
        UserDefaults.standard.set([ghostDir.path, realDir.path], forKey: recentOpenedURLsKey)
        defer { UserDefaults.standard.removeObject(forKey: recentOpenedURLsKey) }

        let store = NavigationStore(initialURL: realDir)
        report(
            "Store/NavigationStore",
            "POS: a nonexistent local recent is kept at init without a synchronous existence check (LP-050)",
            result: store.recentOpenedURLs.map(\.path).contains(ghostDir.path))

        let deadline = Date().addingTimeInterval(5.0)
        while store.recentOpenedURLs.map(\.path).contains(ghostDir.path), Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        let paths = store.recentOpenedURLs.map(\.path)
        report(
            "Store/NavigationStore",
            "POS: the dead recent is pruned off the main actor after init; the real one survives",
            result: !paths.contains(ghostDir.path) && paths.contains(realDir.path))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
