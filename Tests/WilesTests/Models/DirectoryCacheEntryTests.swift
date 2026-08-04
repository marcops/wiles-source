@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct DirectoryCacheEntryTests {
    public static func run() {
        let items = [FileItem(url: URL(fileURLWithPath: "/tmp/a.txt"), icon: NSImage())]
        let loadResult = DirectoryLoadResult(items: items, isPermissionDenied: false)
        let entry = DirectoryCacheEntry(result: loadResult)

        report("Model/DirectoryCacheEntry", "POS: Cache entry wrapped result items count matches", result: entry.result.items.count == 1)
        report("Model/DirectoryCacheEntry", "POS: Cache entry timestamp is valid", result: entry.timestamp <= Date())
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
