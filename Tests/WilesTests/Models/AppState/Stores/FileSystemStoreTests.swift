@testable import Wiles
import Foundation

@MainActor
public struct FileSystemStoreTests {
    public static func run() {
        let store = FileSystemStore()
        report("Store/FileSystemStore", "POS: FileSystemStore items initially empty", result: store.items.isEmpty)
        report("Store/FileSystemStore", "POS: FileSystemStore isLoading initially false", result: !store.isLoading)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
