@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct DirectoryLoadResultTests {
    public static func run() {
        let items = [FileItem(url: URL(fileURLWithPath: "/tmp/b.txt"), icon: NSImage())]
        let result = DirectoryLoadResult(items: items, isPermissionDenied: false)

        report("Model/DirectoryLoadResult", "POS: DirectoryLoadResult items count matches", result: result.items.count == 1)
        report("Model/DirectoryLoadResult", "NEG: DirectoryLoadResult permission denied is false", result: !result.isPermissionDenied)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
