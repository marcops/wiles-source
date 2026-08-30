import Foundation
@testable import Wiles

/// Two branches in `DuplicateDetectionService.scanForDuplicateGroups` are intentionally left
/// uncovered (see `DuplicateDetectionTests.swift` in `Tests/WilesTests/Services/` for the rest of
/// this service's scan-behavior coverage):
/// - `guard let enumerator = fm.enumerator(at:...) else { return empty }`: `FileManager.enumerator(at:)`
///   was verified (see FileSystemSearchAndSortTests.swift's equivalent note) to never actually return
///   nil on macOS, even for a nonexistent path or a non-file URL — no known reachable trigger.
/// - `if scannedCount > maxScannedFileCount { break }` (limit is 50,000): forcing this would require
///   creating 50,001+ real filesystem entries in a temp directory, which would meaningfully slow down
///   every test run for a single defensive cap-guard — disproportionate cost for the risk it guards.
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

        let scanResult = await ((try? DuplicateDetectionService.findDuplicates(in: tempDir)) ?? DuplicateScanResult(groups: [], totalReclaimableBytes: 0))
        report("Feature/DuplicateCleaner", "POS: Duplicate scanner finds 1 duplicate group", result: scanResult.groups.count == 1)
        report("Feature/DuplicateCleaner", "POS: Reclaimable bytes > 0", result: scanResult.totalReclaimableBytes > 0)

        await testUnreadableSubdirDoesNotHideDuplicates()
    }

    /// R1 / BA-509: `scanForDuplicateGroups`'s enumerator now passes `errorHandler: { _, _ in true }`,
    /// so an unreadable nested directory is skipped instead of aborting the scan — which used to drop
    /// every duplicate whose files happened to be enumerated after the protected folder.
    private static func testUnreadableSubdirDoesNotHideDuplicates() async {
        guard getuid() != 0 else {
            report("Feature/DuplicateCleaner", "SKIP (root): unreadable-subdir scan continuation", result: true)
            return
        }
        let fm = FileManager.default
        let root = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("dedup_r1_\(UUID().uuidString)")
        let blocked = root.appendingPathComponent("blocked")
        try? fm.createDirectory(at: blocked, withIntermediateDirectories: true)
        let content = "R1 duplicate payload — long enough to hash meaningfully 0123456789ABCDEF"
        for name in ["a", "b"] {
            let sub = root.appendingPathComponent("sub_\(name)")
            try? fm.createDirectory(at: sub, withIntermediateDirectories: true)
            try? content.write(to: sub.appendingPathComponent("dup.txt"), atomically: true, encoding: .utf8)
        }
        try? "unrelated".write(to: blocked.appendingPathComponent("x.txt"), atomically: true, encoding: .utf8)
        try? fm.setAttributes([.posixPermissions: 0], ofItemAtPath: blocked.path)
        defer {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: blocked.path)
            try? fm.removeItem(at: root)
        }

        let scanResult = await ((try? DuplicateDetectionService.findDuplicates(in: root)) ?? DuplicateScanResult(groups: [], totalReclaimableBytes: 0))
        report(
            "Feature/DuplicateCleaner",
            "POS (R1): a duplicate pair is still found when an unreadable nested directory sits between the two copies",
            result: scanResult.groups.count == 1 && scanResult.groups.first?.items.count == 2)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
