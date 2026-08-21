import Foundation
@testable import Wiles

@MainActor
public struct DuplicateCleanerFeatureTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileA = tempDir.appendingPathComponent("dup1.txt")
        let fileB = tempDir.appendingPathComponent("dup2.txt")
        let content = "Exact Duplicate Content 12345"
        try? content.write(to: fileA, atomically: true, encoding: .utf8)
        try? content.write(to: fileB, atomically: true, encoding: .utf8)

        let scanResult = await DuplicateDetectionService.findDuplicates(in: tempDir)
        report("Feature/DuplicateCleaner", "POS: Duplicate scanner finds 1 duplicate group", result: scanResult.groups.count == 1)
        report("Feature/DuplicateCleaner", "POS: Reclaimable bytes > 0", result: scanResult.totalReclaimableBytes > 0)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
