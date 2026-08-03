import Foundation

@MainActor
public struct SmartFolderTests {
    public static func run() {
        let folder = SmartFolder(name: "PDFs", searchQuery: "kind:pdf", scopePath: "/Users")
        SmartFolderService.saveSmartFolders([folder])
        let loaded = SmartFolderService.loadSavedSmartFolders()
        
        TestReporter.report("SmartFolder", "POS: saveSmartFolders and loadSavedSmartFolders persist folder", result: loaded.contains(where: { $0.name == "PDFs" }))
    }
}
