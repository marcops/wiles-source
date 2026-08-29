import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct DirectoryLoadResultTests {
    public static func run() {
        let tempFile = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("b.txt")
        let items = [FileItem.load(url: tempFile, icon: NSImage())]
        let result = DirectoryLoadResult(items: items)

        report("Model/DirectoryLoadResult", "POS: DirectoryLoadResult items count matches", result: result.items.count == 1)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
