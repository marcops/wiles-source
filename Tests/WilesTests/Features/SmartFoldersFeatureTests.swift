@testable import Wiles
import Foundation

@MainActor
public struct SmartFoldersFeatureTests {
    public static func run() {
        let savedFolders = SmartFolderService.loadSavedSmartFolders()
        defer {
            SmartFolderService.saveSmartFolders(savedFolders)
        }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let dummyFolder = SmartFolder(
            id: UUID(),
            name: "Test Smart Folder",
            searchQuery: "kind:pdf",
            scopePath: tempDir.path
        )

        var currentFolders = savedFolders
        currentFolders.append(dummyFolder)
        SmartFolderService.saveSmartFolders(currentFolders)

        let reloaded = SmartFolderService.loadSavedSmartFolders()
        report("Feature/SmartFolders", "POS: SmartFolderService persists and reloads new smart folder", result: reloaded.contains(where: { $0.id == dummyFolder.id }))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
