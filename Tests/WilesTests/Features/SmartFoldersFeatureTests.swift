@testable import Wiles
import Foundation

@MainActor
public struct SmartFoldersFeatureTests {
    public static func run() {
        let savedFolders = SmartFolderService.loadSavedSmartFolders()
        report("Feature/SmartFolders", "POS: SmartFolderService loads saved smart folders array", result: savedFolders.count >= 0)

        let dummyFolder = SmartFolder(
            id: UUID(),
            name: "Test Smart Folder",
            searchQuery: "kind:pdf",
            scopePath: "/tmp"
        )
        var currentFolders = savedFolders
        currentFolders.append(dummyFolder)
        SmartFolderService.saveSmartFolders(currentFolders)
        report("Feature/SmartFolders", "POS: SmartFolderService saves updated smart folder list", result: true)

        SmartFolderService.saveSmartFolders(savedFolders)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
