@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct AppStateColumnsAndSelectionTests {
    public static func run() {
        testColumnWidth()
        testIsColumnVisible()
        testSetColumnWidth()
        testToggleColumnVisibility()
        testViewModeForFolder()
        testSetViewModeForFolder()
        testHandleSelectionSingleClick()
        testHandleSelectionExtend()
    }

    private static func makeIcon() -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16))
    }

    private static func makeItem(named name: String, in dir: URL) -> FileItem {
        let url = dir.appendingPathComponent(name)
        try? "content".write(to: url, atomically: true, encoding: .utf8)
        return FileItem(url: url, icon: makeIcon())
    }

    private static func testColumnWidth() {
        let appState = AppState()
        // AppState() reads persisted column state from UserDefaults.standard (production code
        // writes every width/visibility change there), so a prior test run or real app usage on
        // this machine can leave stale state — reset explicitly rather than assume a pristine default.
        appState.listColumnStates = ListColumnState.defaults()
        report("AppState+Columns", "POS: columnWidth(for:) returns the column's stored width by default", result: appState.columnWidth(for: .name) == ListColumn.name.defaultWidth)

        // Remove a column's state entirely; should fall back to defaultWidth.
        appState.listColumnStates.removeAll { $0.column == .owner }
        report(
            "AppState+Columns",
            "NEG: columnWidth(for:) falls back to defaultWidth when no state entry exists",
            result: appState.columnWidth(for: .owner) == ListColumn.owner.defaultWidth
        )
    }

    private static func testIsColumnVisible() {
        let appState = AppState()
        // Defaults: name, size, dateModified visible; others hidden.
        report("AppState+Columns", "POS: isColumnVisible() is true for a column marked visible in defaults", result: appState.isColumnVisible(.name) == true)
        report("AppState+Columns", "NEG: isColumnVisible() is false for a column marked hidden in defaults", result: appState.isColumnVisible(.owner) == false)

        // Missing state entry falls back to true.
        appState.listColumnStates.removeAll { $0.column == .group }
        report("AppState+Columns", "NEG: isColumnVisible() defaults to true when no state entry exists", result: appState.isColumnVisible(.group) == true)
    }

    private static func testSetColumnWidth() {
        let appState = AppState()
        appState.setColumnWidth(.size, width: 200)
        report("AppState+Columns", "POS: setColumnWidth() sets an in-range width verbatim", result: appState.columnWidth(for: .size) == 200)

        appState.setColumnWidth(.size, width: 10)
        report(
            "AppState+Columns",
            "NEG: setColumnWidth() clamps a too-small width up to LayoutTokens.columnMinWidth",
            result: appState.columnWidth(for: .size) == LayoutTokens.columnMinWidth
        )

        // No state entry for the column: setColumnWidth should be a no-op (guard returns early).
        appState.listColumnStates.removeAll { $0.column == .kind }
        appState.setColumnWidth(.kind, width: 500)
        report(
            "AppState+Columns",
            "NEG: setColumnWidth() is a no-op when the column has no existing state entry",
            result: appState.listColumnStates.contains { $0.column == .kind } == false
        )
    }

    private static func testToggleColumnVisibility() {
        let appState = AppState()
        let before = appState.isColumnVisible(.owner)
        appState.toggleColumnVisibility(.owner)
        report("AppState+Columns", "POS: toggleColumnVisibility() flips visibility for a normal column", result: appState.isColumnVisible(.owner) == !before)

        appState.toggleColumnVisibility(.owner)
        report("AppState+Columns", "POS: toggleColumnVisibility() flips back on a second call", result: appState.isColumnVisible(.owner) == before)

        // .name is always visible; toggling should have no effect.
        let nameVisibleBefore = appState.isColumnVisible(.name)
        appState.toggleColumnVisibility(.name)
        report(
            "AppState+Columns",
            "NEG: toggleColumnVisibility() is a no-op for the always-visible .name column",
            result: appState.isColumnVisible(.name) == nameVisibleBefore && nameVisibleBefore == true
        )
    }

    private static func testViewModeForFolder() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.preferences.viewMode = .list
        report(
            "AppState+Columns",
            "NEG: viewModeForFolder() falls back to the global viewMode when no per-folder override exists",
            result: appState.viewModeForFolder(dir) == .list
        )

        appState.perFolderViewModes[dir.standardizedFileURL.path] = ViewMode.grid.rawValue
        report("AppState+Columns", "POS: viewModeForFolder() returns the stored per-folder override", result: appState.viewModeForFolder(dir) == .grid)
    }

    private static func testSetViewModeForFolder() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.preferences.viewMode = .list
        appState.setViewModeForFolder(.column, for: dir)
        report(
            "AppState+Columns",
            "POS: setViewModeForFolder() stores the per-folder mode and updates the global viewMode",
            result: appState.perFolderViewModes[dir.standardizedFileURL.path] == ViewMode.column.rawValue && appState.preferences.viewMode == .column
        )

        // A different, untouched folder should not have an override.
        let otherDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        report("AppState+Columns", "NEG: setViewModeForFolder() does not affect unrelated folders", result: appState.perFolderViewModes[otherDir.standardizedFileURL.path] == nil)
    }

    private static func testHandleSelectionSingleClick() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir)
        let itemB = makeItem(named: "b.txt", in: dir)

        appState.selectedURLs = [itemA.url]
        appState.handleSelection(for: itemB, extendSelection: false)
        report(
            "AppState+Selection",
            "POS: handleSelection() without extend replaces the entire selection with the single clicked item",
            result: appState.selectedURLs.count == 1 && appState.selectedURLs.first?.path == itemB.url.path
        )

        report("AppState+Selection", "NEG: handleSelection() without extend clears out any previously selected item", result: appState.selectedURLs.contains(itemA.url) == false)
    }

    private static func testHandleSelectionExtend() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir)
        let itemB = makeItem(named: "b.txt", in: dir)

        appState.selectedURLs = []
        appState.handleSelection(for: itemA, extendSelection: true)
        report("AppState+Selection", "POS: handleSelection() with extend on an empty selection inserts the item", result: appState.selectedURLs == [itemA.url])

        appState.handleSelection(for: itemB, extendSelection: true)
        report("AppState+Selection", "POS: handleSelection() with extend adds a second item alongside the first", result: appState.selectedURLs == Set([itemA.url, itemB.url]))

        appState.handleSelection(for: itemA, extendSelection: true)
        report(
            "AppState+Selection",
            "NEG: handleSelection() with extend on an already-selected item removes it (toggle off), leaving the rest intact",
            result: appState.selectedURLs == Set([itemB.url])
        )

        appState.handleSelection(for: itemB, extendSelection: true)
        report("AppState+Selection", "NEG: handleSelection() with extend toggling off the last item empties the selection", result: appState.selectedURLs.isEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
