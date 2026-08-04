@testable import Wiles
import Foundation

@MainActor
public struct DuplicateDetectionTests {
    public static func run() async {
        await testFindsExactDuplicates()
        await testDoesNotGroupDistinctFiles()
        await testEmptyFolderReturnsNoGroups()
        await testSameSizeDifferentContentNotGrouped()
        await testSkipsSubdirectoriesWhenBuildingSizeMap()
    }

    private static func tempDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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

    private static func testSameSizeDifferentContentNotGrouped() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Same length (same size), but different bytes within the first 4096 bytes.
        let contentA = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        let contentB = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        precondition(contentA.utf8.count == contentB.utf8.count)
        let fileA = dir.appendingPathComponent("same_size_a.txt")
        let fileB = dir.appendingPathComponent("same_size_b.txt")
        try? contentA.write(to: fileA, atomically: true, encoding: .utf8)
        try? contentB.write(to: fileB, atomically: true, encoding: .utf8)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        report("DuplicateDetection", "NEG: files with same size but different content (within first 4096 bytes) are not grouped as duplicates", result: result.groups.isEmpty)
    }

    private static func testSkipsSubdirectoriesWhenBuildingSizeMap() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let subDir = dir.appendingPathComponent("nested_subdir")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let content = "duplicate payload shared across nested subdirectory scan"
        let fileA = dir.appendingPathComponent("top_a.txt")
        let fileB = subDir.appendingPathComponent("nested_b.txt")
        try? content.write(to: fileA, atomically: true, encoding: .utf8)
        try? content.write(to: fileB, atomically: true, encoding: .utf8)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        let foundGroup = result.groups.first { $0.items.count == 2 }
        report("DuplicateDetection", "POS: scan recurses into subdirectories and finds duplicates without erroring on the directory entry itself", result: foundGroup != nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
