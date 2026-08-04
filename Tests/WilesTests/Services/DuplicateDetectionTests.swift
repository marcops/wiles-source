@testable import Wiles
import Foundation

@MainActor
public struct DuplicateDetectionTests {
    public static func run() async {
        await testFindsExactDuplicates()
        await testDoesNotGroupDistinctFiles()
        await testEmptyFolderReturnsNoGroups()
    }

    private static func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private static func testFindsExactDuplicates() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = "duplicate payload content for hashing"
        let fileA = dir.appendingPathComponent("a.txt")
        let fileB = dir.appendingPathComponent("b.txt")
        let fileC = dir.appendingPathComponent("c.txt")
        try? content.write(to: fileA, atomically: true, encoding: .utf8)
        try? content.write(to: fileB, atomically: true, encoding: .utf8)
        try? "totally different unique content".write(to: fileC, atomically: true, encoding: .utf8)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        report("DuplicateDetection", "POS: exact duplicate files (same size+hash) are grouped together", result: result.groups.contains { $0.items.count == 2 })
        report("DuplicateDetection", "POS: reclaimableBytes reflects (count - 1) * size for the duplicate group", result: result.totalReclaimableBytes > 0)
    }

    private static func testDoesNotGroupDistinctFiles() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try? "content one, unique".write(to: dir.appendingPathComponent("one.txt"), atomically: true, encoding: .utf8)
        try? "content two, also unique, different length".write(to: dir.appendingPathComponent("two.txt"), atomically: true, encoding: .utf8)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        report("DuplicateDetection", "NEG: files with different size/content are not grouped as duplicates", result: result.groups.isEmpty)
    }

    private static func testEmptyFolderReturnsNoGroups() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        report("DuplicateDetection", "NEG: empty folder returns zero groups and zero reclaimable bytes", result: result.groups.isEmpty && result.totalReclaimableBytes == 0)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
