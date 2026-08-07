@testable import Wiles
import Foundation

@MainActor
public struct ArchiveInspectorFeatureTests {
    public static func run() async {
        let nonExistentArchive = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nonexistent_\(UUID().uuidString).zip")
        let entries = await ArchiveInspectionService.listEntries(in: nonExistentArchive)
        report("Feature/ArchiveInspector", "NEG: Nonexistent zip returns empty entries", result: entries.isEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
