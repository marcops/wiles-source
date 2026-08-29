import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct AppStateOperationsTests {
    public static func run() {
        testCutSelected()
        testCopySelected()
        testSelectAllItems()
        testOpenSelectedItemNavigatesIn()
        testTriggerQuickLookForSelected()
        testOpenPropertiesForSelected()
        testStartEditingPath()
        testToggleSearching()
        // createNewFileAndRename()'s tests live in AppStateOperationsCreateFolderTests.swift (async
        // companion): since M15/M16 it dispatches via runDetachedFileOperation's Task{} and needs polling.
    }

    private static func makeItem(named name: String, in dir: URL, isDirectory: Bool = false) -> FileItem {
        let url = dir.appendingPathComponent(name)
        if isDirectory {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } else {
            try? "content".write(to: url, atomically: true, encoding: .utf8)
        }
        return FileItem.load(url: url, icon: NSWorkspace.shared.icon(forFile: url.path))
    }

    private static func testCutSelected() {
        let appState = AppState()
        appState.selection.selectedURLs = []
        appState.cutSelected()
        report("AppState+Operations", "NEG: cutSelected() with empty selection leaves clipboard nil", result: appState.transient.clipboard == nil)

        let url = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("cut-\(UUID().uuidString).txt")
        appState.selection.selectedURLs = [url]
        appState.cutSelected()
        report(
            "AppState+Operations",
            "POS: cutSelected() stores selection in clipboard with .cut action",
            result: appState.transient.clipboard?.action == .cut && (appState.transient.clipboard?.isCut(url: url) ?? false))
    }

    private static func testCopySelected() {
        let appState = AppState()
        appState.selection.selectedURLs = []
        appState.copySelected()
        report("AppState+Operations", "NEG: copySelected() with empty selection leaves clipboard nil", result: appState.transient.clipboard == nil)

        let url = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("copy-\(UUID().uuidString).txt")
        appState.selection.selectedURLs = [url]
        appState.copySelected()
        report(
            "AppState+Operations",
            "POS: copySelected() stores selection in clipboard with .copy action",
            result: appState.transient.clipboard?.action == .copy)
    }

    private static func testSelectAllItems() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let items = [makeItem(named: "a.txt", in: dir), makeItem(named: "b.txt", in: dir)]
        appState.fileSystem.items = items
        appState.selection.selectedURLs = []

        appState.selectAllItems()
        report(
            "AppState+Operations",
            "POS: selectAllItems() selects the URL of every item currently listed",
            result: appState.selection.selectedURLs == Set(items.map(\.url)))
    }

    private static func testOpenSelectedItemNavigatesIn() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let subfolder = dir.appendingPathComponent("subfolder")
        try? FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let item = makeItem(named: "subfolder", in: dir, isDirectory: true)
        appState.selection.selectedURLs = [item.url]
        appState.openSelectedItem()
        report(
            "AppState+Operations", "POS: openSelectedItem() navigates into the selected directory",
            result: appState.navigation.currentURL.path == subfolder.standardizedFileURL.path)
    }

    private static func testTriggerQuickLookForSelected() {
        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        appState.selection.selectedURLs = []
        appState.triggerQuickLookForSelected(windowUIState: windowUIState)
        report("AppState+Operations", "NEG: triggerQuickLookForSelected() with no selection leaves quickLookURL nil", result: windowUIState.quickLookURL == nil)

        let url = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("ql-\(UUID().uuidString).txt")
        appState.selection.selectedURLs = [url]
        appState.triggerQuickLookForSelected(windowUIState: windowUIState)
        report("AppState+Operations", "POS: triggerQuickLookForSelected() sets quickLookURL to the selected item", result: windowUIState.quickLookURL == url)
    }

    private static func testOpenPropertiesForSelected() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        let item = makeItem(named: "props.txt", in: dir)
        appState.fileSystem.items = [item]
        appState.selection.selectedURLs = [item.url]
        appState.openPropertiesForSelected(windowUIState: windowUIState)
        report(
            "AppState+Operations",
            "POS: openPropertiesForSelected() sets propertiesItem when the selected URL matches a listed item",
            result: windowUIState.activeModal == .properties(item))

        let appState2 = AppState()
        let windowUIState2 = WindowUIState(preferences: appState2.preferences)
        appState2.fileSystem.items = []
        appState2.selection.selectedURLs = [URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("unknown-\(UUID().uuidString).txt")]
        appState2.openPropertiesForSelected(windowUIState: windowUIState2)
        report(
            "AppState+Operations",
            "NEG: openPropertiesForSelected() stays nil when the selected URL matches no listed item",
            result: windowUIState2.activeModal == nil)
    }

    private static func testStartEditingPath() {
        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        appState.startEditingPath(windowUIState: windowUIState)
        report(
            "AppState+Operations",
            "POS: startEditingPath() copies currentURL.path into pathText and enables editing",
            result: appState.navigation.pathText == appState.navigation.currentURL.path && windowUIState.isEditingPath)
    }

    private static func testToggleSearching() {
        let appState = AppState()
        appState.selection.searchQuery = "leftover query"
        appState.selection.isSearching = false

        appState.toggleSearching()
        report("AppState+Operations", "POS: toggleSearching() enables search mode", result: appState.selection.isSearching)

        appState.toggleSearching()
        report(
            "AppState+Operations",
            "NEG: toggleSearching() off again clears the search query",
            result: !appState.selection.isSearching && appState.selection.searchQuery.isEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
