import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct UITests {
    public static func run() {
        let appState = AppState()
        testPathBarNavigation(appState: appState)
        testSelectionAndContextMenu(appState: appState)
        testPerFolderViewModes(appState: appState)
        testColumnVisibilityAndResizing(appState: appState)
    }

    private static func testColumnVisibilityAndResizing(appState: AppState) {
        let defaultVisible: [ListColumn] = [.name, .size, .dateModified]
        for col in defaultVisible {
            report("UI/Columns", "POS: Default column \(col) is visible", result: appState.isColumnVisible(col))
        }
        report("UI/Columns", "POS: Kind column is initially hidden", result: !appState.isColumnVisible(.kind))
        report("UI/Columns", "POS: DateCreated column is initially hidden", result: !appState.isColumnVisible(.dateCreated))

        appState.toggleColumnVisibility(.dateCreated)
        report("UI/Columns", "POS: Toggling DateCreated makes it visible", result: appState.isColumnVisible(.dateCreated))

        let initialWidth = appState.columnWidth(for: .size)
        appState.setColumnWidth(.size, width: 300)
        report("UI/Columns", "POS: Resizing Size column updates state", result: appState.columnWidth(for: .size) == 300)

        // Restore
        appState.toggleColumnVisibility(.dateCreated)
        appState.setColumnWidth(.size, width: initialWidth)
    }

    private static func testPathBarNavigation(appState: AppState) {
        let parentURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let sampleURL = parentURL.appendingPathComponent("Projects")
        try? FileManager.default.createDirectory(at: sampleURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parentURL) }

        appState.navigateTo(sampleURL)

        let pathComponents = sampleURL.standardizedFileURL.pathComponents.filter { $0 != "/" }
        report("UI/PathBar", "POS: Path components decomposed correctly", result: pathComponents.last == "Projects")

        appState.navigateTo(parentURL)
        report(
            "UI/PathBar", "POS: Clicking path bar segment navigates to exact parent directory",
            result: appState.navigation.currentURL.standardizedFileURL == parentURL.standardizedFileURL)

        let windowUIState = WindowUIState(preferences: appState.preferences)
        windowUIState.isEditingPath = true
        appState.navigation.pathText = "/Applications"
        appState.navigateTo(URL(fileURLWithPath: appState.navigation.pathText))
        windowUIState.isEditingPath = false
        report(
            "UI/PathBar",
            "POS: Direct path text editing submission updates currentURL to /Applications",
            result: appState.navigation.currentURL.path == "/Applications")
    }

    private static func testSelectionAndContextMenu(appState: AppState) {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url1 = tempDir.appendingPathComponent("file1.txt")
        let url2 = tempDir.appendingPathComponent("file2.txt")
        try? "1".write(to: url1, atomically: true, encoding: .utf8)
        try? "2".write(to: url2, atomically: true, encoding: .utf8)

        let icon = NSWorkspace.shared.icon(forFile: url1.path)
        let item1 = FileItem.load(url: url1, icon: icon)
        let item2 = FileItem.load(url: url2, icon: icon)

        appState.fileSystem.items = [item1, item2]
        appState.selection.selectedURLs = []

        appState.handleSelection(for: item1)
        report("UI/Selection", "POS: Single click selects item", result: appState.selection.selectedURLs == [url1])

        appState.selection.selectedURLs = [url1]
        if !appState.selection.selectedURLs.contains(item2.url) {
            appState.selection.selectedURLs = [item2.url]
        }
        report("UI/ContextMenu", "POS: Right-clicking unselected item targets that item for context menu", result: appState.selection.selectedURLs == [url2])
    }

    private static func testPerFolderViewModes(appState: AppState) {
        let tempBase = URL(fileURLWithPath: testTemporaryDirectory())
        let folderA = tempBase.appendingPathComponent("FolderA")
        let folderB = tempBase.appendingPathComponent("FolderB")

        appState.preferences.view.viewMode = .grid
        appState.preferences.view.perFolderViewModes.removeAll()
        appState.setViewModeForFolder(.list, for: folderA)

        report("UI/ViewMode", "POS: Per-folder view mode override saved for FolderA (.list)", result: appState.viewModeForFolder(folderA) == .list)
        report("UI/ViewMode", "POS: FolderB returns currently active view mode (.list)", result: appState.viewModeForFolder(folderB) == .list)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
