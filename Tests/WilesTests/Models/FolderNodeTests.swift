@testable import Wiles
import Foundation

@MainActor
public struct FolderNodeTests {
    public static func run() {
        let rootTree = FolderNode.buildRootTree()
        report("Model/FolderNode", "POS: Root tree builds with name 'Root (/)'", result: rootTree.name == "Root (/)")
        report("Model/FolderNode", "POS: Root tree URL path is root '/'", result: rootTree.url.path == "/")

        let leafNode = FolderNode(id: URL(fileURLWithPath: "/tmp"), name: "tmp", url: URL(fileURLWithPath: "/tmp"), children: nil)
        report("Model/FolderNode", "NEG: Leaf node children is nil", result: leafNode.children == nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
