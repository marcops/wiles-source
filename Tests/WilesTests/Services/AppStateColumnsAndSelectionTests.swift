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
        testRemapPerFolderViewMode()
        testRemapRelocatedState()
        testHandleSelectionSingleClick()
        testHandleSelectionExtend()
        testHandleSelectionMouseShiftClickUsesStableAnchor()
        testHandleSelectionMouseCmdClick()
        testPrimarySelectedURL()
        testAutoFitColumnWidth()
        testPerformRenameNoOpCases()
        // testPerformRenameFailurePath lives in AppStateColumnsAndActionsAsyncTests.swift (async
        // companion) since performRename() dispatches via Task{} and needs polling.
    }

    private static func makeIcon() -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16))
    }

    private static func makeItem(named name: String, in dir: URL) -> FileItem {
        let url = dir.appendingPathComponent(name)
        try? "content".write(to: url, atomically: true, encoding: .utf8)
        return FileItem.load(url: url, icon: makeIcon())
    }

    private static func testColumnWidth() {
        let appState = AppState()
        // AppState() reads persisted column state from UserDefaults.standard (production code
        // writes every width/visibility change there), so a prior test run or real app usage on
        // this machine can leave stale state — reset explicitly rather than assume a pristine default.
        appState.preferences.view.listColumnStates = ListColumnState.defaults()
        report(
            "AppState+Columns",
            "POS: columnWidth(for:) returns the column's stored width by default",
            result: appState.columnWidth(for: .name) == ListColumn.name.defaultWidth)

        // Remove a column's state entirely; should fall back to defaultWidth.
        appState.preferences.view.listColumnStates.removeAll { $0.column == .owner }
        report(
            "AppState+Columns",
            "NEG: columnWidth(for:) falls back to defaultWidth when no state entry exists",
            result: appState.columnWidth(for: .owner) == ListColumn.owner.defaultWidth)
    }

    private static func testIsColumnVisible() {
        let appState = AppState()
        // Defaults: name, size, dateModified visible; others hidden.
        report("AppState+Columns", "POS: isColumnVisible() is true for a column marked visible in defaults", result: appState.isColumnVisible(.name))
        report("AppState+Columns", "NEG: isColumnVisible() is false for a column marked hidden in defaults", result: !appState.isColumnVisible(.owner))

        // Missing state entry falls back to true.
        appState.preferences.view.listColumnStates.removeAll { $0.column == .group }
        report("AppState+Columns", "NEG: isColumnVisible() defaults to true when no state entry exists", result: appState.isColumnVisible(.group))
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
        appState.preferences.view.listColumnStates.removeAll { $0.column == .kind }
        appState.setColumnWidth(.kind, width: 500)
        report(
            "AppState+Columns",
            "NEG: setColumnWidth() is a no-op when the column has no existing state entry",
            result: !appState.preferences.view.listColumnStates.contains { $0.column == .kind })
    }

    /// `setColumnWidth(_:width:persist:)` with `persist: false` (used by `ColumnResizeHandle`'s
    /// `DragGesture.onChanged` on every mouse-move delta) must update `listColumnStates` in memory
    /// without triggering `AppState.listColumnStates`'s `didSet` -> `saveListColumnStates()` write to
    /// `UserDefaults.standard`. `preferences.view.saveListColumnStates()` (called once from `.onEnded`) must then persist
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
        appState.preferences.view.listColumnStates = ListColumnState.defaults()
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

        appState.preferences.view.saveListColumnStates()
        report("AppState+Columns", "POS: saveListColumnStates() persists the width set earlier with persist: false", result: persistedWidth(for: .size) == 321)
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
            result: appState.isColumnVisible(.name) == nameVisibleBefore && nameVisibleBefore)
    }

    private static func testViewModeForFolder() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.preferences.view.viewMode = .list
        report(
            "AppState+Columns",
            "NEG: viewModeForFolder() falls back to the global viewMode when no per-folder override exists",
            result: appState.viewModeForFolder(dir) == .list)

        // Per-folder overrides only apply once opted into via Advanced Settings.
        appState.preferences.view.perFolderViewModeEnabled = true
        appState.preferences.view.perFolderViewModes[dir.standardizedFileURL.path] = ViewMode.grid.rawValue
        report("AppState+Columns", "POS: viewModeForFolder() returns the stored per-folder override", result: appState.viewModeForFolder(dir) == .grid)
    }

    private static func testSetViewModeForFolder() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.preferences.view.viewMode = .list
        // Per-folder overrides only apply once opted into via Advanced Settings.
        appState.preferences.view.perFolderViewModeEnabled = true
        appState.setViewModeForFolder(.grid, for: dir)
        report(
            "AppState+Columns",
            "POS: setViewModeForFolder() stores the per-folder mode and updates the global viewMode",
            result: appState.preferences.view.perFolderViewModes[dir.standardizedFileURL.path] == ViewMode.grid.rawValue && appState.preferences.view
                .viewMode == .grid)

        // A different, untouched folder should not have an override.
        let otherDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        report(
            "AppState+Columns",
            "NEG: setViewModeForFolder() does not affect unrelated folders",
            result: appState.preferences.view.perFolderViewModes[otherDir.standardizedFileURL.path] == nil)
    }

    /// L20: `remapPerFolderViewMode(from:to:)` moves a stored per-folder view mode from the old path
    /// key to the new one after an in-app relocation, so the key isn't orphaned. Restores the real
    /// `perFolderViewModes` through the store (per rule 17) so its debounced save re-captures real data.
    private static func testRemapPerFolderViewMode() {
        let appState = AppState()
        let priorModes = appState.preferences.view.perFolderViewModes
        defer { appState.preferences.view.perFolderViewModes = priorModes }
        appState.preferences.view.perFolderViewModes = [:]
        let oldURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("old-\(UUID().uuidString)")
        let newURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("new-\(UUID().uuidString)")
        appState.preferences.view.perFolderViewModes[oldURL.standardizedFileURL.path] = ViewMode.list.rawValue

        appState.remapPerFolderViewMode(from: oldURL, to: newURL)
        report(
            "AppState+Columns",
            "POS: remapPerFolderViewMode() moves the stored mode from the old path key to the new one",
            result: appState.preferences.view.perFolderViewModes[oldURL.standardizedFileURL.path] == nil
                && appState.preferences.view.perFolderViewModes[newURL.standardizedFileURL.path] == ViewMode.list.rawValue)

        let untracked = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("untracked-\(UUID().uuidString)")
        let before = appState.preferences.view.perFolderViewModes
        appState.remapPerFolderViewMode(from: untracked, to: newURL)
        report(
            "AppState+Columns",
            "NEG: remapPerFolderViewMode() is a no-op when the old path has no stored per-folder mode",
            result: appState.preferences.view.perFolderViewModes == before)
    }

    /// L20: `remapRelocatedState(from:to:)` performs both `remapFavorites` and
    /// `remapPerFolderViewMode` for one in-app move. Restores both stores through their properties.
    private static func testRemapRelocatedState() {
        let appState = AppState()
        let priorModes = appState.preferences.view.perFolderViewModes
        let priorFavorites = appState.preferences.favorites.favoriteURLs
        defer {
            appState.preferences.view.perFolderViewModes = priorModes
            appState.preferences.favorites.favoriteURLs = priorFavorites
        }
        appState.preferences.view.perFolderViewModes = [:]
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let oldURL = dir.appendingPathComponent("Reports").standardizedFileURL
        let newURL = dir.appendingPathComponent("Archive/Reports").standardizedFileURL
        appState.preferences.favorites.favoriteURLs = [oldURL]
        appState.preferences.view.perFolderViewModes[oldURL.path] = ViewMode.grid.rawValue

        let oldParent = oldURL.deletingLastPathComponent()
        let newParent = newURL.deletingLastPathComponent()
        let sample = DirectoryLoadResult(items: [])
        DirectoryCacheService.shared.cacheDirectory(sample, for: oldParent)
        DirectoryCacheService.shared.cacheDirectory(sample, for: newParent)

        appState.remapRelocatedState(from: oldURL, to: newURL)
        report(
            "AppState+Columns",
            "POS: remapRelocatedState() remaps both the favorite and the per-folder view mode key to the new path",
            result: appState.preferences.favorites.favoriteURLs == [newURL]
                && appState.preferences.view.perFolderViewModes[oldURL.path] == nil
                && appState.preferences.view.perFolderViewModes[newURL.path] == ViewMode.grid.rawValue)
        report(
            "AppState+Columns",
            "POS: remapRelocatedState() drops the cached listing of both the source and destination parent directories",
            result: DirectoryCacheService.shared.cachedResult(for: oldParent) == nil
                && DirectoryCacheService.shared.cachedResult(for: newParent) == nil)
    }

    private static func testHandleSelectionSingleClick() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir)
        let itemB = makeItem(named: "b.txt", in: dir)

        appState.selection.selectedURLs = [itemA.url]
        appState.handleSelection(for: itemB, extendSelection: false)
        report(
            "AppState+Selection",
            "POS: handleSelection() without extend replaces the entire selection with the single clicked item",
            result: appState.selection.selectedURLs.count == 1 && appState.selection.selectedURLs.first?.path == itemB.url.path)

        report(
            "AppState+Selection",
            "NEG: handleSelection() without extend clears out any previously selected item",
            result: !appState.selection.selectedURLs.contains(itemA.url))
    }

    private static func testHandleSelectionExtend() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir)
        let itemB = makeItem(named: "b.txt", in: dir)

        appState.selection.selectedURLs = []
        appState.handleSelection(for: itemA, extendSelection: true)
        report(
            "AppState+Selection",
            "POS: handleSelection() with extend on an empty selection inserts the item",
            result: appState.selection.selectedURLs == [itemA.url])

        appState.handleSelection(for: itemB, extendSelection: true)
        report(
            "AppState+Selection",
            "POS: handleSelection() with extend adds a second item alongside the first",
            result: appState.selection.selectedURLs == Set([itemA.url, itemB.url]))

        appState.handleSelection(for: itemA, extendSelection: true)
        report(
            "AppState+Selection",
            "NEG: handleSelection() with extend on an already-selected item removes it (toggle off), leaving the rest intact",
            result: appState.selection.selectedURLs == Set([itemB.url]))

        appState.handleSelection(for: itemB, extendSelection: true)
        report(
            "AppState+Selection",
            "NEG: handleSelection() with extend toggling off the last item empties the selection",
            result: appState.selection.selectedURLs.isEmpty)
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

        appState.selection.selectedURLs = []
        appState.handleSelection(for: itemB, modifierFlags: [])
        report("AppState+Selection", "POS: plain click sets the keyboard selection anchor", result: appState.selection.keyboardSelectionAnchorURL == itemB.url)

        appState.handleSelection(for: itemB, modifierFlags: .command)
        report(
            "AppState+Selection",
            "POS: cmd-click on the anchor item toggles it off but leaves the anchor in place",
            result: appState.selection.selectedURLs.isEmpty && appState.selection.keyboardSelectionAnchorURL == itemB.url)

        appState.handleSelection(for: itemD, modifierFlags: .shift)
        report(
            "AppState+Selection",
            "POS: shift-click after the anchor item was deselected still ranges from the stable anchor (B) through D, not just the clicked item",
            result: appState.selection.selectedURLs == Set([itemB.url, itemC.url, itemD.url]))
    }

    private static func testHandleSelectionMouseCmdClick() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir)
        let itemB = makeItem(named: "b.txt", in: dir)
        appState.fileSystem.items = [itemA, itemB]

        appState.selection.selectedURLs = [itemA.url]
        appState.handleSelection(for: itemB, modifierFlags: .command)
        report(
            "AppState+Selection",
            "POS: cmd-click adds to the existing selection instead of replacing it",
            result: appState.selection.selectedURLs == Set([itemA.url, itemB.url]))

        appState.handleSelection(for: itemA, modifierFlags: [])
        report(
            "AppState+Selection",
            "POS: a plain click (no modifiers) still replaces the whole selection with just the clicked item",
            result: appState.selection.selectedURLs == [itemA.url])
    }

    /// `primarySelectedURL` must not use `selectedURLs.first` (a `Set`, arbitrary order) for the
    /// single-target action item — it uses the keyboard anchor while still selected, otherwise the
    /// first selected item in visible order.
    private static func testPrimarySelectedURL() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir)
        let itemB = makeItem(named: "b.txt", in: dir)
        let itemC = makeItem(named: "c.txt", in: dir)
        appState.fileSystem.items = [itemA, itemB, itemC]

        report("AppState+Selection", "NEG: primarySelectedURL is nil with an empty selection", result: appState.primarySelectedURL == nil)

        appState.selection.selectedURLs = [itemB.url, itemC.url]
        appState.selection.keyboardSelectionAnchorURL = itemC.url
        report(
            "AppState+Selection",
            "POS: primarySelectedURL returns the keyboard anchor when it is still part of the selection",
            result: appState.primarySelectedURL == itemC.url)

        appState.selection.keyboardSelectionAnchorURL = itemA.url // no longer selected
        report(
            "AppState+Selection",
            "POS: primarySelectedURL falls back to the first selected item in visible order when the anchor is not selected",
            result: appState.primarySelectedURL == itemB.url)
    }

    private static func testAutoFitColumnWidth() {
        let appState = AppState()
        appState.preferences.view.listColumnStates = ListColumnState.defaults()
        // Start from a known width that's guaranteed to differ from the auto-fit result below.
        appState.setColumnWidth(.name, width: LayoutTokens.columnMinWidth)

        appState.autoFitColumnWidth(.name)
        let expected = max(LayoutTokens.columnMinWidth, ColumnAutoFitService.calculateAutoFitWidth(
            for: .name,
            items: appState.fileSystem.items,
            iconSize: appState.preferences.view.iconSize,
            language: appState.preferences.appearance.appLanguage))
        report(
            "AppState+Columns",
            "POS: autoFitColumnWidth() applies the width computed by ColumnAutoFitService, clamped via setColumnWidth()",
            result: appState.columnWidth(for: .name) == expected)

        // No state entry for the column: setColumnWidth's internal guard makes this a no-op.
        appState.preferences.view.listColumnStates.removeAll { $0.column == .size }
        appState.autoFitColumnWidth(.size)
        report(
            "AppState+Columns",
            "NEG: autoFitColumnWidth() is a no-op when the column has no existing state entry",
            result: !appState.preferences.view.listColumnStates.contains { $0.column == .size })
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

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
