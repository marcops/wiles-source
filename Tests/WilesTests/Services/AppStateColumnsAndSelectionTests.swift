import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct AppStateColumnsAndSelectionTests {
    public static func run() {
        testColumnWidth()
        testIsColumnVisible()
        testSetColumnWidth()
        testSetColumnWidthPersistFlagDefersUserDefaultsWrite()
        testToggleColumnVisibility()
        testViewModeForFolder()
        testSetViewModeForFolder()
        testHandleSelectionSingleClick()
        testHandleSelectionExtend()
        testHandleSelectionMouseShiftClickUsesStableAnchor()
        testHandleSelectionMouseCmdClick()
        testAutoFitColumnWidth()
        testPerformRenameNoOpCases()
        testPerformRenameFailurePath()
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
        appState.preferences.listColumnStates = ListColumnState.defaults()
        report(
            "AppState+Columns",
            "POS: columnWidth(for:) returns the column's stored width by default",
            result: appState.columnWidth(for: .name) == ListColumn.name.defaultWidth)

        // Remove a column's state entirely; should fall back to defaultWidth.
        appState.preferences.listColumnStates.removeAll { $0.column == .owner }
        report(
            "AppState+Columns",
            "NEG: columnWidth(for:) falls back to defaultWidth when no state entry exists",
            result: appState.columnWidth(for: .owner) == ListColumn.owner.defaultWidth)
    }

    private static func testIsColumnVisible() {
        let appState = AppState()
        // Defaults: name, size, dateModified visible; others hidden.
        report("AppState+Columns", "POS: isColumnVisible() is true for a column marked visible in defaults", result: appState.isColumnVisible(.name) == true)
        report("AppState+Columns", "NEG: isColumnVisible() is false for a column marked hidden in defaults", result: appState.isColumnVisible(.owner) == false)

        // Missing state entry falls back to true.
        appState.preferences.listColumnStates.removeAll { $0.column == .group }
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
            result: appState.columnWidth(for: .size) == LayoutTokens.columnMinWidth)

        // No state entry for the column: setColumnWidth should be a no-op (guard returns early).
        appState.preferences.listColumnStates.removeAll { $0.column == .kind }
        appState.setColumnWidth(.kind, width: 500)
        report(
            "AppState+Columns",
            "NEG: setColumnWidth() is a no-op when the column has no existing state entry",
            result: appState.preferences.listColumnStates.contains { $0.column == .kind } == false)
    }

    /// `setColumnWidth(_:width:persist:)` with `persist: false` (used by `ColumnResizeHandle`'s
    /// `DragGesture.onChanged` on every mouse-move delta) must update `listColumnStates` in memory
    /// without triggering `AppState.listColumnStates`'s `didSet` -> `saveListColumnStates()` write to
    /// `UserDefaults.standard`. `persistColumnWidths()` (called once from `.onEnded`) must then persist
    /// the final width. `AppState`/`PreferencesStore` have no injectable `UserDefaults` suite, so per
    /// rule 17 this snapshots and restores the real `wiles_listColumnStates` key in `defer`.
    private static func testSetColumnWidthPersistFlagDefersUserDefaultsWrite() {
        let key = DefaultsKey.listColumnStates.rawValue
        let priorData = UserDefaults.standard.data(forKey: key)
        defer {
            if let priorData {
                UserDefaults.standard.set(priorData, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        func persistedWidth(for column: ListColumn) -> CGFloat? {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let states = try? JSONDecoder().decode([ListColumnState].self, from: data) else { return nil }
            return states.first { $0.column == column }?.width
        }

        let appState = AppState()
        appState.preferences.listColumnStates = ListColumnState.defaults()
        // Establish a known persisted baseline distinct from the width we're about to drag to.
        appState.setColumnWidth(.size, width: 150, persist: true)
        report("AppState+Columns", "POS: setColumnWidth(persist: true) (the default) persists immediately", result: persistedWidth(for: .size) == 150)

        appState.setColumnWidth(.size, width: 321, persist: false)
        report(
            "AppState+Columns",
            "POS: setColumnWidth(persist: false) updates the in-memory width immediately",
            result: appState.columnWidth(for: .size) == 321)
        report(
            "AppState+Columns",
            "NEG: setColumnWidth(persist: false) does not write the new width to UserDefaults yet",
            result: persistedWidth(for: .size) == 150 && persistedWidth(for: .size) != 321)

        appState.persistColumnWidths()
        report("AppState+Columns", "POS: persistColumnWidths() persists the width set earlier with persist: false", result: persistedWidth(for: .size) == 321)
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
            result: appState.isColumnVisible(.name) == nameVisibleBefore && nameVisibleBefore == true)
    }

    private static func testViewModeForFolder() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.preferences.viewMode = .list
        report(
            "AppState+Columns",
            "NEG: viewModeForFolder() falls back to the global viewMode when no per-folder override exists",
            result: appState.viewModeForFolder(dir) == .list)

        appState.preferences.perFolderViewModes[dir.standardizedFileURL.path] = ViewMode.grid.rawValue
        report("AppState+Columns", "POS: viewModeForFolder() returns the stored per-folder override", result: appState.viewModeForFolder(dir) == .grid)
    }

    private static func testSetViewModeForFolder() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.preferences.viewMode = .list
        appState.setViewModeForFolder(.grid, for: dir)
        report(
            "AppState+Columns",
            "POS: setViewModeForFolder() stores the per-folder mode and updates the global viewMode",
            result: appState.preferences.perFolderViewModes[dir.standardizedFileURL.path] == ViewMode.grid.rawValue && appState.preferences.viewMode == .grid)

        // A different, untouched folder should not have an override.
        let otherDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        report(
            "AppState+Columns",
            "NEG: setViewModeForFolder() does not affect unrelated folders",
            result: appState.preferences.perFolderViewModes[otherDir.standardizedFileURL.path] == nil)
    }

    private static func testHandleSelectionSingleClick() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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
            result: appState.selectedURLs.count == 1 && appState.selectedURLs.first?.path == itemB.url.path)

        report(
            "AppState+Selection",
            "NEG: handleSelection() without extend clears out any previously selected item",
            result: appState.selectedURLs.contains(itemA.url) == false)
    }

    private static func testHandleSelectionExtend() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir)
        let itemB = makeItem(named: "b.txt", in: dir)

        appState.selectedURLs = []
        appState.handleSelection(for: itemA, extendSelection: true)
        report("AppState+Selection", "POS: handleSelection() with extend on an empty selection inserts the item", result: appState.selectedURLs == [itemA.url])

        appState.handleSelection(for: itemB, extendSelection: true)
        report(
            "AppState+Selection",
            "POS: handleSelection() with extend adds a second item alongside the first",
            result: appState.selectedURLs == Set([itemA.url, itemB.url]))

        appState.handleSelection(for: itemA, extendSelection: true)
        report(
            "AppState+Selection",
            "NEG: handleSelection() with extend on an already-selected item removes it (toggle off), leaving the rest intact",
            result: appState.selectedURLs == Set([itemB.url]))

        appState.handleSelection(for: itemB, extendSelection: true)
        report(
            "AppState+Selection",
            "NEG: handleSelection() with extend toggling off the last item empties the selection",
            result: appState.selectedURLs.isEmpty)
    }

    /// Regression for the mouse-click `handleSelection(for:)` overload anchoring shift-click
    /// ranges on `selectedURLs.first` — `Set` has no stable order, and here the anchor item is
    /// deselected before the shift-click, so the old code's optional bind on `.first` fails
    /// entirely (selection is empty) and silently falls back to a single-item click instead of
    /// a range. The fix anchors on `selection.keyboardSelectionAnchorURL` instead, matching the
    /// existing Shift+Arrow keyboard anchor (see `SelectionStore.swift`).
    private static func testHandleSelectionMouseShiftClickUsesStableAnchor() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir)
        let itemB = makeItem(named: "b.txt", in: dir)
        let itemC = makeItem(named: "c.txt", in: dir)
        let itemD = makeItem(named: "d.txt", in: dir)
        appState.fileSystem.items = [itemA, itemB, itemC, itemD]

        appState.selectedURLs = []
        appState.handleSelection(for: itemB, modifierFlags: [])
        report("AppState+Selection", "POS: plain click sets the keyboard selection anchor", result: appState.selection.keyboardSelectionAnchorURL == itemB.url)

        appState.handleSelection(for: itemB, modifierFlags: .command)
        report(
            "AppState+Selection",
            "POS: cmd-click on the anchor item toggles it off but leaves the anchor in place",
            result: appState.selectedURLs.isEmpty && appState.selection.keyboardSelectionAnchorURL == itemB.url)

        appState.handleSelection(for: itemD, modifierFlags: .shift)
        report(
            "AppState+Selection",
            "POS: shift-click after the anchor item was deselected still ranges from the stable anchor (B) through D, not just the clicked item",
            result: appState.selectedURLs == Set([itemB.url, itemC.url, itemD.url]))
    }

    private static func testHandleSelectionMouseCmdClick() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir)
        let itemB = makeItem(named: "b.txt", in: dir)
        appState.fileSystem.items = [itemA, itemB]

        appState.selectedURLs = [itemA.url]
        appState.handleSelection(for: itemB, modifierFlags: .command)
        report(
            "AppState+Selection",
            "POS: cmd-click adds to the existing selection instead of replacing it",
            result: appState.selectedURLs == Set([itemA.url, itemB.url]))

        appState.handleSelection(for: itemA, modifierFlags: [])
        report(
            "AppState+Selection",
            "POS: a plain click (no modifiers) still replaces the whole selection with just the clicked item",
            result: appState.selectedURLs == [itemA.url])
    }

    private static func testAutoFitColumnWidth() {
        let appState = AppState()
        appState.preferences.listColumnStates = ListColumnState.defaults()
        // Start from a known width that's guaranteed to differ from the auto-fit result below.
        appState.setColumnWidth(.name, width: LayoutTokens.columnMinWidth)

        appState.autoFitColumnWidth(.name)
        let expected = max(LayoutTokens.columnMinWidth, ColumnAutoFitService.calculateAutoFitWidth(
            for: .name,
            items: appState.fileSystem.items,
            iconSize: appState.preferences.iconSize,
            language: appState.preferences.appLanguage))
        report(
            "AppState+Columns",
            "POS: autoFitColumnWidth() applies the width computed by ColumnAutoFitService, clamped via setColumnWidth()",
            result: appState.columnWidth(for: .name) == expected)

        // No state entry for the column: setColumnWidth's internal guard makes this a no-op.
        appState.preferences.listColumnStates.removeAll { $0.column == .size }
        appState.autoFitColumnWidth(.size)
        report(
            "AppState+Columns",
            "NEG: autoFitColumnWidth() is a no-op when the column has no existing state entry",
            result: appState.preferences.listColumnStates.contains { $0.column == .size } == false)
    }

    private static func testPerformRenameNoOpCases() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let item = makeItem(named: "original.txt", in: dir)

        appState.performRename(item: item, newName: "   ")
        report(
            "AppState+Columns",
            "NEG: performRename() with an all-whitespace name is a no-op and leaves the file untouched",
            result: FileManager.default.fileExists(atPath: item.url.path))

        appState.performRename(item: item, newName: item.name)
        report(
            "AppState+Columns",
            "NEG: performRename() with the item's unchanged name is a no-op",
            result: FileManager.default.fileExists(atPath: item.url.path))
    }

    private static func testPerformRenameFailurePath() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.modal.errorMessage = nil
        let item = makeItem(named: "source.txt", in: dir)
        _ = makeItem(named: "taken.txt", in: dir)

        appState.performRename(item: item, newName: "taken.txt")
        report(
            "AppState+Columns",
            "NEG: performRename() surfaces an error via showError() when FileSystemService.renameItem() throws (destination name already taken)",
            result: appState.modal.errorMessage != nil && FileManager.default.fileExists(atPath: item.url.path))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
