@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct AppStateNavigationExtraTests {
    public static func run() {
        testAddToRecentsPrependsAndDedups()
        testAddToRecentsCapsAt50()
        testAddToRecentsIgnoresRecentsVirtualURL()
        testAddToRecentsIgnoresWilesScheme()
        testNavigateToRecentsVirtualURLUpdatesStateAndHistory()
        testNavigateToSameURLDoesNotPushHistory()
        testNavigateToWithAddToHistoryFalseDoesNotPushHistory()
        testGoBackDoesNotDropForwardOnRepeatedCalls()
        testGoUpAtRootDoesNotNavigate()
    }

    // MARK: - Helpers

    private static func tempDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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

        appState.recentOpenedURLs = []
        let urlA = dir.appendingPathComponent("a.txt")
        let urlB = dir.appendingPathComponent("b.txt")
        appState.addToRecents(urlA)
        appState.addToRecents(urlB)
        report(
            "Navigation/Recents",
            "POS: addToRecents() inserts new URL at front",
            result: appState.recentOpenedURLs.first?.path == urlB.standardizedFileURL.path
        )

        // Re-adding 'a' should move it to front, not duplicate it.
        appState.addToRecents(urlA)
        let paths = appState.recentOpenedURLs.map { $0.path }
        report(
            "Navigation/Recents",
            "POS: addToRecents() moves re-added URL to front without duplicating",
            result: paths.first == urlA.standardizedFileURL.path && paths.filter { $0 == urlA.standardizedFileURL.path }.count == 1
        )
    }

    private static func testAddToRecentsCapsAt50() {
        let appState = AppState()
        let dir = tempDir()
        appState.recentOpenedURLs = (0..<50).map { dir.appendingPathComponent("f\($0).txt").standardizedFileURL }
        let overflow = dir.appendingPathComponent("overflow.txt")
        appState.addToRecents(overflow)
        report("Navigation/Recents", "POS: addToRecents() caps the list at 50 entries", result: appState.recentOpenedURLs.count == 50)
        report(
            "Navigation/Recents",
            "POS: addToRecents() keeps newest entry after capping at 50",
            result: appState.recentOpenedURLs.first?.path == overflow.standardizedFileURL.path
        )
    }

    private static func testAddToRecentsIgnoresRecentsVirtualURL() {
        let appState = AppState()
        appState.recentOpenedURLs = []
        appState.addToRecents(AppState.recentsVirtualURL)
        report("Navigation/Recents", "NEG: addToRecents() ignores the recents virtual URL", result: appState.recentOpenedURLs.isEmpty)
    }

    private static func testAddToRecentsIgnoresWilesScheme() {
        let appState = AppState()
        appState.recentOpenedURLs = []
        guard let wilesURL = URL(string: "wiles://some/path") else {
            report("Navigation/Recents", "NEG: addToRecents() ignores wiles:// scheme URLs", result: false)
            return
        }
        appState.addToRecents(wilesURL)
        report("Navigation/Recents", "NEG: addToRecents() ignores wiles:// scheme URLs", result: appState.recentOpenedURLs.isEmpty)
    }

    // MARK: - navigateTo / recentsVirtualURL

    private static func testNavigateToRecentsVirtualURLUpdatesStateAndHistory() {
        let appState = AppState()
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        appState.navigateTo(dir)
        appState.selectedURLs = [dir.appendingPathComponent("x.txt")]
        appState.isSearching = true
        appState.searchQuery = "abc"

        appState.navigateTo(AppState.recentsVirtualURL)
        report("Navigation/RecentsVirtual", "POS: navigateTo(recentsVirtualURL) sets currentURL to the virtual URL", result: appState.currentURL == AppState.recentsVirtualURL)
        report("Navigation/RecentsVirtual", "POS: navigateTo(recentsVirtualURL) clears selection", result: appState.selectedURLs.isEmpty)
        report("Navigation/RecentsVirtual", "POS: navigateTo(recentsVirtualURL) clears search state", result: appState.isSearching == false && appState.searchQuery.isEmpty)

        // goBack should return to the real directory we came from.
        appState.goBack()
        report("Navigation/RecentsVirtual", "POS: goBack() from recentsVirtualURL restores prior real directory", result: appState.currentURL.path == dir.standardizedFileURL.path)
    }

    // MARK: - history push suppression

    private static func testNavigateToSameURLDoesNotPushHistory() {
        let appState = AppState()
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        appState.navigateTo(dir)
        let backCountAfterFirstNav = appState.historyBack.count

        // Navigating to the same URL again should not push a duplicate history entry.
        appState.navigateTo(dir)
        report("Navigation/History", "NEG: navigateTo() with the same URL does not push a duplicate history entry", result: appState.historyBack.count == backCountAfterFirstNav)
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
        let backCountBefore = appState.historyBack.count
        appState.navigateTo(dirB, addToHistory: false)
        report(
            "Navigation/History",
            "NEG: navigateTo(addToHistory: false) does not push history",
            result: appState.historyBack.count == backCountBefore && appState.currentURL.path == dirB.standardizedFileURL.path
        )
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
        let initial = appState.currentURL

        appState.navigateTo(dirA)
        appState.navigateTo(dirB)
        appState.goBack()
        report("Navigation/History", "POS: goBack() after two navigations returns to the previous stop", result: appState.currentURL.path == dirA.standardizedFileURL.path)

        // A fresh navigation should clear the forward stack.
        appState.navigateTo(initial)
        report("Navigation/History", "NEG: navigateTo() after goBack() clears the forward stack", result: appState.historyForward.isEmpty)
    }

    // MARK: - goUp

    private static func testGoUpAtRootDoesNotNavigate() {
        let appState = AppState()
        let root = URL(fileURLWithPath: "/")
        appState.currentURL = root
        appState.goUp()
        report("Navigation/GoUp", "NEG: goUp() at the filesystem root does not navigate (parent == self)", result: appState.currentURL.path == root.path)
    }
}
