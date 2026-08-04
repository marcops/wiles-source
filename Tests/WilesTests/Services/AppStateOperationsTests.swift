@testable import Wiles
import Foundation
import AppKit

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
    }

    private static func makeItem(named name: String, in dir: URL, isDirectory: Bool = false) -> FileItem {
        let url = dir.appendingPathComponent(name)
        if isDirectory {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } else {
            try? "content".write(to: url, atomically: true, encoding: .utf8)
        }
        return FileItem(url: url, icon: NSWorkspace.shared.icon(forFile: url.path))
    }

    private static func testCutSelected() {
        let appState = AppState()
        appState.selectedURLs = []
        appState.cutSelected()
        report("AppState+Operations", "NEG: cutSelected() with empty selection leaves clipboard nil", result: appState.clipboard == nil)

        let url = URL(fileURLWithPath: "/tmp/cut-\(UUID().uuidString).txt")
        appState.selectedURLs = [url]
        appState.cutSelected()
        report("AppState+Operations", "POS: cutSelected() stores selection in clipboard with .cut action", result: appState.clipboard?.action == .cut && appState.clipboard?.isCut(url: url) == true)
    }

    private static func testCopySelected() {
        let appState = AppState()
        appState.selectedURLs = []
        appState.copySelected()
        report("AppState+Operations", "NEG: copySelected() with empty selection leaves clipboard nil", result: appState.clipboard == nil)

        let url = URL(fileURLWithPath: "/tmp/copy-\(UUID().uuidString).txt")
        appState.selectedURLs = [url]
        appState.copySelected()
        report("AppState+Operations", "POS: copySelected() stores selection in clipboard with .copy action", result: appState.clipboard?.action == .copy)
    }

    private static func testSelectAllItems() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let items = [makeItem(named: "a.txt", in: dir), makeItem(named: "b.txt", in: dir)]
        appState.items = items
        appState.selectedURLs = []

        appState.selectAllItems()
        report("AppState+Operations", "POS: selectAllItems() selects the URL of every item currently listed", result: appState.selectedURLs == Set(items.map { $0.url }))
    }

    private static func testOpenSelectedItemNavigatesIn() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let subfolder = dir.appendingPathComponent("subfolder")
        try? FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let item = makeItem(named: "subfolder", in: dir, isDirectory: true)
        appState.selectedURLs = [item.url]
        appState.openSelectedItem()
        report("AppState+Operations", "POS: openSelectedItem() navigates into the selected directory", result: appState.currentURL.standardizedFileURL == subfolder.standardizedFileURL)
    }

    private static func testTriggerQuickLookForSelected() {
        let appState = AppState()
        appState.selectedURLs = []
        appState.triggerQuickLookForSelected()
        report("AppState+Operations", "NEG: triggerQuickLookForSelected() with no selection leaves quickLookURL nil", result: appState.quickLookURL == nil)

        let url = URL(fileURLWithPath: "/tmp/ql-\(UUID().uuidString).txt")
        appState.selectedURLs = [url]
        appState.triggerQuickLookForSelected()
        report("AppState+Operations", "POS: triggerQuickLookForSelected() sets quickLookURL to the selected item", result: appState.quickLookURL == url)
    }

    private static func testOpenPropertiesForSelected() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let item = makeItem(named: "props.txt", in: dir)
        appState.items = [item]
        appState.selectedURLs = [item.url]
        appState.openPropertiesForSelected()
        report("AppState+Operations", "POS: openPropertiesForSelected() sets propertiesItem when the selected URL matches a listed item", result: appState.propertiesItem?.url == item.url)

        let appState2 = AppState()
        appState2.items = []
        appState2.selectedURLs = [URL(fileURLWithPath: "/tmp/unknown-\(UUID().uuidString).txt")]
        appState2.openPropertiesForSelected()
        report("AppState+Operations", "NEG: openPropertiesForSelected() stays nil when the selected URL matches no listed item", result: appState2.propertiesItem == nil)
    }

    private static func testStartEditingPath() {
        let appState = AppState()
        appState.startEditingPath()
        report("AppState+Operations", "POS: startEditingPath() copies currentURL.path into pathText and enables editing", result: appState.pathText == appState.currentURL.path && appState.isEditingPath == true)
    }

    private static func testToggleSearching() {
        let appState = AppState()
        appState.searchQuery = "leftover query"
        appState.isSearching = false

        appState.toggleSearching()
        report("AppState+Operations", "POS: toggleSearching() enables search mode", result: appState.isSearching == true)

        appState.toggleSearching()
        report("AppState+Operations", "NEG: toggleSearching() off again clears the search query", result: appState.isSearching == false && appState.searchQuery.isEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
