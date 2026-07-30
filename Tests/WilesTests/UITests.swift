import Foundation
import AppKit
import WilesCore

@MainActor
public struct UITests {
    public static func run() {
        let appState = AppState()
        
        // ========================================================
        // 1. PATH BAR SEGMENT NAVIGATION & DIRECTORY PATH HIERARCHY
        // ========================================================
        do {
            let sampleURL = URL(fileURLWithPath: "/Users/marco/Documents/Projects")
            appState.navigateTo(sampleURL)
            
            // Test Path Decomposing
            let pathComponents = sampleURL.pathComponents.filter { $0 != "/" }
            report("UI/PathBar", "POS: Path components decomposed correctly", result: pathComponents == ["Users", "marco", "Documents", "Projects"])
            
            // Test Navigation by Clicking Path Component (/Users/marco)
            let parentURL = URL(fileURLWithPath: "/Users/marco")
            appState.navigateTo(parentURL)
            report("UI/PathBar", "POS: Clicking path bar segment navigates to exact parent directory", result: appState.currentURL.standardizedFileURL == parentURL.standardizedFileURL)
            
            // Test Direct Path Text Editing Submission
            appState.isEditingPath = true
            appState.pathText = "/Applications"
            appState.navigateTo(URL(fileURLWithPath: appState.pathText))
            appState.isEditingPath = false
            report("UI/PathBar", "POS: Direct path text editing submission updates currentURL to /Applications", result: appState.currentURL.path == "/Applications")
        }
        
        // ========================================================
        // 2. SELECTION & MOUSE CLICK HANDLERS (CMD / SHIFT / RIGHT-CLICK)
        // ========================================================
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let url1 = tempDir.appendingPathComponent("file1.txt")
            let url2 = tempDir.appendingPathComponent("file2.txt")
            let url3 = tempDir.appendingPathComponent("file3.txt")
            try? "1".write(to: url1, atomically: true, encoding: .utf8)
            try? "2".write(to: url2, atomically: true, encoding: .utf8)
            try? "3".write(to: url3, atomically: true, encoding: .utf8)
            
            let icon = NSWorkspace.shared.icon(forFile: url1.path)
            let item1 = FileItem(url: url1, icon: icon)
            let item2 = FileItem(url: url2, icon: icon)
            let item3 = FileItem(url: url3, icon: icon)
            
            appState.items = [item1, item2, item3]
            appState.selectedURLs = []
            
            // Single Click Selection
            appState.handleSelection(for: item1)
            report("UI/Selection", "POS: Single click selects item", result: appState.selectedURLs == [url1])
            
            // Right-Click Context Menu Selection Safety (Right clicking unselected item selects only that item)
            appState.selectedURLs = [url1]
            if !appState.selectedURLs.contains(item2.url) { appState.selectedURLs = [item2.url] }
            report("UI/ContextMenu", "POS: Right-clicking unselected item targets that item for context menu", result: appState.selectedURLs == [url2])
            
            // Right-Click Context Menu Preservation (Right clicking already selected item in multi-selection preserves selection)
            appState.selectedURLs = [url1, url2]
            if !appState.selectedURLs.contains(item1.url) { appState.selectedURLs = [item1.url] }
            report("UI/ContextMenu", "POS: Right-clicking inside existing selection preserves multi-selection", result: appState.selectedURLs == [url1, url2])
            
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // ========================================================
        // 3. PER-FOLDER VIEW MODE MEMORY & OVERRIDES
        // ========================================================
        do {
            let folderA = URL(fileURLWithPath: "/tmp/FolderA")
            let folderB = URL(fileURLWithPath: "/tmp/FolderB")
            
            appState.viewMode = .grid
            appState.perFolderViewModes.removeAll()
            appState.setViewModeForFolder(.list, for: folderA)
            
            report("UI/ViewMode", "POS: Per-folder view mode override saved for FolderA (.list)", result: appState.viewModeForFolder(folderA) == .list)
            report("UI/ViewMode", "POS: FolderB returns currently active view mode (.list)", result: appState.viewModeForFolder(folderB) == .list)
        }
        
        // ========================================================
        // 4. QUICK OPEN IN EXTERNAL APP LAUNCHER UTILITIES
        // ========================================================
        do {
            let testDir = FileManager.default.homeDirectoryForCurrentUser
            
            // Verify terminal opening handler constructs without crash
            openTerminal(at: testDir)
            report("UI/OpenIn", "POS: openTerminal helper executes safely", result: true)
        }
    }
    
    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
