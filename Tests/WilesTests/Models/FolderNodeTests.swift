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
        testLoadChildrenOfNonexistentFolderReturnsEmpty()
        testLoadChildrenSkipsPlainFiles()
    }

    /// Covers `loadSubfolders`'s `guard let urls = try? fm.contentsOfDirectory(...) else { return [] }`
    /// failure branch — a folder that doesn't exist on disk returns an empty array rather than throwing.
    private static func testLoadChildrenOfNonexistentFolderReturnsEmpty() {
        let missing = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        let children = FolderNode.loadChildren(of: missing)
        report("Model/FolderNode", "NEG: loadChildren(of:) for a nonexistent folder returns an empty array", result: children.isEmpty)
    }

    /// Covers the `guard isDir else { return nil }` filter inside `loadSubfolders`'s `compactMap` —
    /// a plain file sitting alongside real subfolders must be skipped, not turned into a node.
    private static func testLoadChildrenSkipsPlainFiles() {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let subfolder = root.appendingPathComponent("realFolder")
        let plainFile = root.appendingPathComponent("notAFolder.txt")
        defer { try? fm.removeItem(at: root) }

        try? fm.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try? "x".write(to: plainFile, atomically: true, encoding: .utf8)

        let children = FolderNode.loadChildren(of: root)
        report(
            "Model/FolderNode",
            "NEG: loadChildren(of:) skips plain files, returning only the real subfolder",
            result: children.count == 1 && children.first?.name == "realFolder")
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
