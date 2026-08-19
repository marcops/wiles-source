import Foundation
@testable import Wiles

@MainActor
public struct FolderNodeTests {
    public static func run() {
        let rootTree = FolderNode.buildRootTree()
        report("Model/FolderNode", "POS: Root tree builds with name 'Root (/)'", result: rootTree.name == "Root (/)")
        report("Model/FolderNode", "POS: Root tree URL path is root '/'", result: rootTree.url.path == "/")

        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let leafNode = FolderNode(id: tempDir, name: "temp", url: tempDir, children: nil, hasSubfolders: false)
        report("Model/FolderNode", "NEG: Leaf node children is nil", result: leafNode.children == nil)

        testLoadChildrenLazyHasSubfolders()
    }

    /// Regression coverage for the sidebar directory tree bug: `loadChildren(of:)` doesn't eagerly
    /// recurse into its results, but `hasSubfolders` must still reflect reality so the UI knows to
    /// show a disclosure arrow for a folder it hasn't loaded children for yet.
    private static func testLoadChildrenLazyHasSubfolders() {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let withNestedSubfolder = root.appendingPathComponent("withNestedSubfolder")
        let nestedSubfolder = withNestedSubfolder.appendingPathComponent("nested")
        let emptyFolder = root.appendingPathComponent("emptyFolder")
        defer { try? fm.removeItem(at: root) }

        try? fm.createDirectory(at: nestedSubfolder, withIntermediateDirectories: true)
        try? fm.createDirectory(at: emptyFolder, withIntermediateDirectories: true)

        let children = FolderNode.loadChildren(of: root).sorted { $0.name < $1.name }
        report("Model/FolderNode", "POS: loadChildren finds both immediate subfolders", result: children.count == 2)

        let withNested = children.first { $0.name == "withNestedSubfolder" }
        report("Model/FolderNode", "POS: a folder with a nested subfolder has hasSubfolders true", result: withNested?.hasSubfolders == true)
        report("Model/FolderNode", "NEG: loadChildren doesn't eagerly recurse — children stays nil", result: withNested?.children == nil)

        let empty = children.first { $0.name == "emptyFolder" }
        report("Model/FolderNode", "NEG: a folder with no subfolders has hasSubfolders false", result: empty?.hasSubfolders == false)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
