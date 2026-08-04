@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct ArrowKeyNavigationTests {
    public static func run() {
        testMoveSelectionDown()
        testMoveSelectionUp()
        testMoveSelectionBoundaryClamp()
        testMoveSelectionFromEmpty()
        testMoveSelectionShiftExtend()
        testArrowRightEntersDirectory()
        testArrowLeftGoesUp()
        testDefaultColumns()
    }

    // MARK: - Helpers

    private static func makeItems(in dir: URL, names: [String]) -> [FileItem] {
        names.map { name in
            let url = dir.appendingPathComponent(name)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return FileItem(url: url, icon: icon)
        }
    }

    private static func tempDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private static func simulateMoveSelection(by offset: Int, isShift: Bool, appState: AppState) {
        let items = appState.items
        guard !items.isEmpty else { return }
        let anchorURL = appState.selectedURLs.first
        let anchorIndex = items.firstIndex(where: { $0.url == anchorURL }) ?? -1
        let newIndex = max(0, min(items.count - 1, anchorIndex + offset))
        let newURL = items[newIndex].url
        if isShift && anchorIndex >= 0 {
            let lo = min(anchorIndex, newIndex)
            let hi = max(anchorIndex, newIndex)
            appState.selectedURLs = Set(items[lo...hi].map { $0.url })
        } else {
            appState.selectedURLs = [newURL]
        }
    }

    // MARK: - Tests

    private static func testMoveSelectionDown() {
        let appState = AppState()
        let dir = tempDir()
        let items = makeItems(in: dir, names: ["a.txt", "b.txt", "c.txt"])
        appState.items = items
        appState.selectedURLs = [items[0].url]
        simulateMoveSelection(by: 1, isShift: false, appState: appState)
        report("Navigation/ArrowKeys", "POS: ↓ moves selection to next item", result: appState.selectedURLs == [items[1].url])
    }

    private static func testMoveSelectionUp() {
        let appState = AppState()
        let dir = tempDir()
        let items = makeItems(in: dir, names: ["a.txt", "b.txt", "c.txt"])
        appState.items = items
        appState.selectedURLs = [items[2].url]
        simulateMoveSelection(by: -1, isShift: false, appState: appState)
        report("Navigation/ArrowKeys", "POS: ↑ moves selection to previous item", result: appState.selectedURLs == [items[1].url])
    }

    private static func testMoveSelectionBoundaryClamp() {
        let appState = AppState()
        let dir = tempDir()
        let items = makeItems(in: dir, names: ["only.txt"])
        appState.items = items
        appState.selectedURLs = [items[0].url]
        simulateMoveSelection(by: 1, isShift: false, appState: appState)
        report("Navigation/ArrowKeys", "NEG: ↓ at last item stays on last item", result: appState.selectedURLs == [items[0].url])
        simulateMoveSelection(by: -1, isShift: false, appState: appState)
        report("Navigation/ArrowKeys", "NEG: ↑ at first item stays on first item", result: appState.selectedURLs == [items[0].url])
    }

    private static func testMoveSelectionFromEmpty() {
        let appState = AppState()
        let dir = tempDir()
        let items = makeItems(in: dir, names: ["a.txt", "b.txt"])
        appState.items = items
        appState.selectedURLs = []
        simulateMoveSelection(by: 1, isShift: false, appState: appState)
        report("Navigation/ArrowKeys", "POS: ↓ with no selection selects first item", result: appState.selectedURLs == [items[0].url])
    }

    private static func testMoveSelectionShiftExtend() {
        let appState = AppState()
        let dir = tempDir()
        let items = makeItems(in: dir, names: ["a.txt", "b.txt", "c.txt"])
        appState.items = items
        appState.selectedURLs = [items[0].url]
        simulateMoveSelection(by: 2, isShift: true, appState: appState)
        let expected: Set<URL> = Set(items.map { $0.url })
        report("Navigation/ArrowKeys", "POS: Shift+↓ extends range selection", result: appState.selectedURLs == expected)
    }

    private static func testArrowRightEntersDirectory() {
        let appState = AppState()
        let parentDir = tempDir()
        let childDir = parentDir.appendingPathComponent("subfolder")
        try? FileManager.default.createDirectory(at: childDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parentDir) }

        let icon = NSWorkspace.shared.icon(forFile: childDir.path)
        let dirItem = FileItem(url: childDir, icon: icon)
        appState.items = [dirItem]
        appState.selectedURLs = [dirItem.url]
        // Simulate → on a directory in List View
        if let first = appState.selectedURLs.first,
           let item = appState.items.first(where: { $0.url == first }),
           item.isDirectory {
            appState.navigateTo(first)
        }
        report("Navigation/ArrowKeys", "POS: → navigates into selected directory in List View", result: appState.currentURL.standardizedFileURL == childDir.standardizedFileURL)
    }

    private static func testArrowLeftGoesUp() {
        let appState = AppState()
        let parentDir = tempDir()
        let childDir = parentDir.appendingPathComponent("subfolder")
        try? FileManager.default.createDirectory(at: childDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parentDir) }

        appState.navigateTo(childDir)
        appState.goUp()
        report("Navigation/ArrowKeys", "POS: ← (goUp) navigates to parent directory", result: appState.currentURL.path == parentDir.standardizedFileURL.path)
    }

    private static func testDefaultColumns() {
        let appState = AppState()
        appState.listColumnStates = ListColumnState.defaults()
        report("Navigation/ListColumns", "POS: Default columns are name, size, dateModified only", result:
            appState.isColumnVisible(.name) &&
            appState.isColumnVisible(.size) &&
            appState.isColumnVisible(.dateModified) &&
            !appState.isColumnVisible(.kind) &&
            !appState.isColumnVisible(.dateCreated)
        )
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
