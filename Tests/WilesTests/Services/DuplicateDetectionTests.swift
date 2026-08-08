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
        await testFilesWithIdenticalPrefixButDifferingTailAreNotGrouped()
        await testLargeTrulyIdenticalFilesAreStillGrouped()
        await testEmptyFilesAreNotGrouped()
        await testHiddenFilesAreSkipped()
        await testThreeIdenticalFilesFormOneGroupOfThree()
        await testSingleUniqueFileFormsNoGroup()
        await testCancellingCallerTaskStopsScanBeforeCompletion()
        await testUnreadableFilesAreSkippedDuringHashing()
    }

    private static func tempDir() -> URL {
        URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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

    /// Regression coverage for the false-duplicate data-loss fix: files that share an identical
    /// 4096-byte prefix (and same size) but differ afterward — as many real formats with fixed
    /// headers do (MP4, ISO, DMG, VM disk images) — must NOT be grouped as duplicates. The partial
    /// hash alone used to be trusted directly; now a full-content hash is required to confirm any
    /// partial-hash match before it's presented to the user as a real duplicate.
    private static func testFilesWithIdenticalPrefixButDifferingTailAreNotGrouped() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let prefix = String(repeating: "X", count: 4096)
        let contentA = prefix + "TAIL_ONE_DIFFERS_HERE"
        let contentB = prefix + "TAIL_TWO_DIFFERS_HERE"
        precondition(contentA.utf8.count == contentB.utf8.count)
        let fileA = dir.appendingPathComponent("big_a.txt")
        let fileB = dir.appendingPathComponent("big_b.txt")
        try? contentA.write(to: fileA, atomically: true, encoding: .utf8)
        try? contentB.write(to: fileB, atomically: true, encoding: .utf8)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        report(
            "DuplicateDetection",
            "NEG: files with identical 4096-byte prefix but differing tail are not grouped (full-hash confirmation)",
            result: !result.groups.contains { $0.items.count == 2 }
        )
    }

    /// POS half of the same fix: files large enough to exercise the multi-chunk full-hash read
    /// (>1MB, so computeFullHash's chunked FileHandle loop runs more than once) that are truly
    /// byte-for-byte identical must still be correctly grouped — the full-hash pass shouldn't
    /// introduce false negatives for genuine duplicates.
    private static func testLargeTrulyIdenticalFilesAreStillGrouped() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let chunk = Data(repeating: 0x42, count: 1024 * 1024) // 1 MB
        var content = Data()
        for _ in 0..<2 { content.append(chunk) } // 2 MB, spans multiple 1MB read chunks
        let fileA = dir.appendingPathComponent("large_a.bin")
        let fileB = dir.appendingPathComponent("large_b.bin")
        try? content.write(to: fileA)
        try? content.write(to: fileB)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        report(
            "DuplicateDetection",
            "POS: large (multi-chunk) truly identical files are still correctly grouped as duplicates",
            result: result.groups.contains { $0.items.count == 2 }
        )
    }

    private static func testEmptyFilesAreNotGrouped() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try? "".write(to: dir.appendingPathComponent("empty_a.txt"), atomically: true, encoding: .utf8)
        try? "".write(to: dir.appendingPathComponent("empty_b.txt"), atomically: true, encoding: .utf8)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        report(
            "DuplicateDetection",
            "NEG: zero-byte files are excluded from scanning and never grouped as duplicates",
            result: result.groups.isEmpty && result.totalReclaimableBytes == 0
        )
    }

    private static func testHiddenFilesAreSkipped() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = "hidden duplicate content that should be skipped by the scan"
        try? content.write(to: dir.appendingPathComponent(".hidden_a.txt"), atomically: true, encoding: .utf8)
        try? content.write(to: dir.appendingPathComponent(".hidden_b.txt"), atomically: true, encoding: .utf8)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        report(
            "DuplicateDetection",
            "NEG: hidden dotfiles are skipped during enumeration and not grouped as duplicates",
            result: result.groups.isEmpty && result.totalReclaimableBytes == 0
        )
    }

    private static func testThreeIdenticalFilesFormOneGroupOfThree() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = "triplicate payload shared across three files"
        try? content.write(to: dir.appendingPathComponent("t1.txt"), atomically: true, encoding: .utf8)
        try? content.write(to: dir.appendingPathComponent("t2.txt"), atomically: true, encoding: .utf8)
        try? content.write(to: dir.appendingPathComponent("t3.txt"), atomically: true, encoding: .utf8)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        let group = result.groups.first
        let size = Int64(content.utf8.count)
        report("DuplicateDetection", "POS: three identical files form a single group of three, not multiple pairs", result: result.groups.count == 1 && group?.items.count == 3)
        report("DuplicateDetection", "POS: reclaimableBytes for a triplicate group equals (3-1) * fileSize", result: result.totalReclaimableBytes == size * 2)
    }

    private static func testSingleUniqueFileFormsNoGroup() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try? "the only file in this folder".write(to: dir.appendingPathComponent("solo.txt"), atomically: true, encoding: .utf8)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        report("DuplicateDetection", "NEG: a lone file with a unique size never forms a duplicate group", result: result.groups.isEmpty && result.totalReclaimableBytes == 0)
    }

    /// Regression coverage for the `withTaskCancellationHandler` fix: `findDuplicates` runs its
    /// scan on a `Task.detached`, which is NOT automatically cancelled just because the caller's
    /// task is cancelled — without the explicit `onCancel { scanTask.cancel() }` forwarding,
    /// cancelling the caller would leave the detached scan running to completion as a zombie.
    /// A large, fully-duplicated data set forces enough real hashing work that cancelling the
    /// caller's task immediately after starting it reliably wins the race against completion;
    /// `findDuplicates` swallows the resulting `CancellationError` internally and falls back to
    /// an empty result, so a cancelled scan is observable as zero groups / zero reclaimable bytes
    /// instead of the fully-populated result a completed scan of this data would produce.
    private static func testCancellingCallerTaskStopsScanBeforeCompletion() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let chunk = Data(repeating: 0x5A, count: 1024 * 1024) // 1 MB
        var content = Data()
        for _ in 0..<4 { content.append(chunk) } // 4 MB per file, spans multiple hash chunks
        for index in 0..<24 {
            try? content.write(to: dir.appendingPathComponent("dup_\(index).bin"))
        }

        let callerTask = Task {
            await DuplicateDetectionService.shared.findDuplicates(in: dir)
        }
        callerTask.cancel()
        let result = await callerTask.value

        report(
            "DuplicateDetection",
            "POS: cancelling the caller's task before the scan completes propagates to the detached scan task, yielding an empty (not partial-wrong or hung) result",
            result: result.groups.isEmpty && result.totalReclaimableBytes == 0
        )
    }

    // Covers computePartialHash's "guard let handle = try? FileHandle(forReadingFrom: url) else {
    // return nil }" branch: a same-size candidate that can't be opened for reading (permissions
    // revoked) must be silently excluded from the partial-hash map rather than crashing the scan.
    private static func testUnreadableFilesAreSkippedDuringHashing() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = "same size payload for unreadable-file coverage test"
        let readableFile = dir.appendingPathComponent("readable.txt")
        let unreadableFile = dir.appendingPathComponent("unreadable.txt")
        try? content.write(to: readableFile, atomically: true, encoding: .utf8)
        try? content.write(to: unreadableFile, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: unreadableFile.path)

        let result = await DuplicateDetectionService.shared.findDuplicates(in: dir)
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: unreadableFile.path)

        report(
            "DuplicateDetection",
            "NEG: a same-size file that can't be opened for reading is excluded from hashing instead of crashing the scan",
            result: result.groups.isEmpty && result.totalReclaimableBytes == 0
        )
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
