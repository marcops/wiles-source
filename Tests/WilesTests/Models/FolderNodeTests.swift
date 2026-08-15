import Foundation
@testable import Wiles

@MainActor
public struct FolderNodeTests {
    public static func run() {
        let rootTree = FolderNode.buildRootTree()
        report("Model/FolderNode", "POS: Root tree builds with name 'Root (/)'", result: rootTree.name == "Root (/)")
        report("Model/FolderNode", "POS: Root tree URL path is root '/'", result: rootTree.url.path == "/")

        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let leafNode = FolderNode(id: tempDir, name: "temp", url: tempDir, children: nil)
        report("Model/FolderNode", "NEG: Leaf node children is nil", result: leafNode.children == nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
