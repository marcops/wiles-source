@testable import Wiles
import Foundation

@MainActor
public struct SmartFolderTests {
    public static func run() {
        let folder = SmartFolder(name: "PDFs", searchQuery: "kind:pdf", scopePath: "/Users")
        SmartFolderService.saveSmartFolders([folder])
        let loaded = SmartFolderService.loadSavedSmartFolders()

        TestReporter.report("SmartFolder", "POS: saveSmartFolders and loadSavedSmartFolders persist folder", result: loaded.contains(where: { $0.name == "PDFs" }))

        testEmptyArrayRoundTrip()
        testMultipleFoldersFieldByFieldRoundTrip()
    }

    private static func testEmptyArrayRoundTrip() {
        // POS: saving an empty array clears out any leftover data from previous saves
        SmartFolderService.saveSmartFolders([])
        let loaded = SmartFolderService.loadSavedSmartFolders()
        TestReporter.report("SmartFolder", "POS: saving an empty array then loading returns an empty array", result: loaded.isEmpty)
    }

    private static func testMultipleFoldersFieldByFieldRoundTrip() {
        let tempScopeA = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
        let tempScopeB = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
        let tempScopeC = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path

        let folderA = SmartFolder(name: "Images", icon: "photo", searchQuery: "kind:image", scopePath: tempScopeA)
        let folderB = SmartFolder(name: "Large Files", icon: "doc.fill", searchQuery: "size:>100mb", scopePath: tempScopeB)
        let folderC = SmartFolder(name: "Recent Downloads", icon: "arrow.down.circle", searchQuery: "kind:any", scopePath: tempScopeC)

        SmartFolderService.saveSmartFolders([folderA, folderB, folderC])
        let loaded = SmartFolderService.loadSavedSmartFolders()

        guard loaded.count == 3,
              let loadedA = loaded.first(where: { $0.id == folderA.id }),
              let loadedB = loaded.first(where: { $0.id == folderB.id }),
              let loadedC = loaded.first(where: { $0.id == folderC.id }) else {
            TestReporter.report("SmartFolder", "POS: saving multiple folders preserves all fields exactly on round-trip", result: false)
            return
        }

        let fieldsMatch =
            loadedA.name == folderA.name && loadedA.icon == folderA.icon &&
            loadedA.searchQuery == folderA.searchQuery && loadedA.scopePath == folderA.scopePath &&
            loadedB.name == folderB.name && loadedB.icon == folderB.icon &&
            loadedB.searchQuery == folderB.searchQuery && loadedB.scopePath == folderB.scopePath &&
            loadedC.name == folderC.name && loadedC.icon == folderC.icon &&
            loadedC.searchQuery == folderC.searchQuery && loadedC.scopePath == folderC.scopePath

        TestReporter.report(
            "SmartFolder", "POS: saving multiple folders preserves name, icon, searchQuery, and scopePath exactly on round-trip",
            result: fieldsMatch
        )

        // Clean up so this test doesn't leak state into subsequent runs.
        SmartFolderService.saveSmartFolders([])
    }
}
