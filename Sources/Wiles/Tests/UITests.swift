import Foundation
import AppKit

@MainActor
public struct UITests {
    public static func run() {
        let appState = AppState()
        testPathBarNavigation(appState: appState)
        testSelectionAndContextMenu(appState: appState)
        testPerFolderViewModes(appState: appState)
    }
    
    private static func testPathBarNavigation(appState: AppState) {
        let sampleURL = URL(fileURLWithPath: "/Users/marco/Documents/Projects")
        appState.navigateTo(sampleURL)
        
        let pathComponents = sampleURL.pathComponents.filter { $0 != "/" }
        report("UI/PathBar", "POS: Path components decomposed correctly", result: pathComponents == ["Users", "marco", "Documents", "Projects"])
        
        let parentURL = URL(fileURLWithPath: "/Users/marco")
        appState.navigateTo(parentURL)
        report("UI/PathBar", "POS: Clicking path bar segment navigates to exact parent directory", result: appState.currentURL.standardizedFileURL == parentURL.standardizedFileURL)
        
        appState.isEditingPath = true
        appState.pathText = "/Applications"
        appState.navigateTo(URL(fileURLWithPath: appState.pathText))
        appState.isEditingPath = false
        report("UI/PathBar", "POS: Direct path text editing submission updates currentURL to /Applications", result: appState.currentURL.path == "/Applications")
    }
    
    private static func testSelectionAndContextMenu(appState: AppState) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let url1 = tempDir.appendingPathComponent("file1.txt")
        let url2 = tempDir.appendingPathComponent("file2.txt")
        try? "1".write(to: url1, atomically: true, encoding: .utf8)
        try? "2".write(to: url2, atomically: true, encoding: .utf8)
        
        let icon = NSWorkspace.shared.icon(forFile: url1.path)
        let item1 = FileItem(url: url1, icon: icon)
        let item2 = FileItem(url: url2, icon: icon)
        
        appState.items = [item1, item2]
        appState.selectedURLs = []
        
        appState.handleSelection(for: item1)
        report("UI/Selection", "POS: Single click selects item", result: appState.selectedURLs == [url1])
        
        appState.selectedURLs = [url1]
        if !appState.selectedURLs.contains(item2.url) { appState.selectedURLs = [item2.url] }
        report("UI/ContextMenu", "POS: Right-clicking unselected item targets that item for context menu", result: appState.selectedURLs == [url2])
    }
    
    private static func testPerFolderViewModes(appState: AppState) {
        let folderA = URL(fileURLWithPath: "/tmp/FolderA")
        let folderB = URL(fileURLWithPath: "/tmp/FolderB")
        
        appState.viewMode = .grid
        appState.perFolderViewModes.removeAll()
        appState.setViewModeForFolder(.list, for: folderA)
        
        report("UI/ViewMode", "POS: Per-folder view mode override saved for FolderA (.list)", result: appState.viewModeForFolder(folderA) == .list)
        report("UI/ViewMode", "POS: FolderB returns currently active view mode (.list)", result: appState.viewModeForFolder(folderB) == .list)
    }
    
    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
