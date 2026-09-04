import Foundation
@testable import Wiles

@MainActor
public struct DiskSpaceVisualizerFeatureTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("data.bin")
        try? Data(repeating: 0x41, count: 1024).write(to: file)

        let reportResult = await ((try? DiskSpaceVisualizerService.calculateDiskUsage(for: tempDir)) ?? DiskUsageReport(
            totalSize: 0,
            topItems: [],
            othersItem: nil))
        report("Feature/DiskSpaceVisualizer", "POS: Disk space report calculates totalSize > 0", result: reportResult.totalSize >= 1024)
        report("Feature/DiskSpaceVisualizer", "POS: Report contains topItems", result: !reportResult.topItems.isEmpty)

        await testMissingFolderThrows()
        await testEmptyFolderReturnsEmptyReport()
        await testSubfolderSizeIsIncludedViaComputeFolderSizeFast()
        await testOthersBucketAggregatesItemsPastTop10()
        await testUnreadableSubdirDoesNotAbortSizeWalk()
        testComputeFolderSizeFastStopsOnTheFileCapAndTheWallClockBudget()
    }

    /// MM-081: the file cap is 50k (aligned with `DuplicateDetectionService`) so the chart doesn't
    /// under-scan a big folder and misrank it, and a shared wall-clock budget is what actually bounds
    /// a pathological scan. Both stop conditions flag the folder truncated (→ `isApproximate`).
    private static func testComputeFolderSizeFastStopsOnTheFileCapAndTheWallClockBudget() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for index in 0 ..< 40 {
            try? Data(repeating: 0x41, count: 100).write(to: dir.appendingPathComponent("f\(index).bin"))
        }

        let full = (try? DiskSpaceVisualizerService.computeFolderSizeFast(folderURL: dir)) ?? (total: Int64(0), wasTruncated: false)
        report(
            "Feature/DiskSpaceVisualizer",
            "POS: a small folder well under both caps is scanned in full (not flagged truncated)",
            result: full.total == 4000 && !full.wasTruncated)

        let fileCapped = (try? DiskSpaceVisualizerService.computeFolderSizeFast(
            folderURL: dir, maxFiles: 10)) ?? (total: Int64(0), wasTruncated: false)
        report(
            "Feature/DiskSpaceVisualizer",
            "POS: hitting the file cap stops the walk early and flags the folder truncated",
            result: fileCapped.wasTruncated && fileCapped.total < full.total && fileCapped.total > 0)

        let timeCapped = (try? DiskSpaceVisualizerService.computeFolderSizeFast(
            folderURL: dir, deadline: .now, wallClockCheckInterval: 4)) ?? (total: Int64(0), wasTruncated: false)
        report(
            "Feature/DiskSpaceVisualizer",
            "POS: passing the wall-clock deadline stops the walk and flags the folder truncated",
            result: timeCapped.wasTruncated && timeCapped.total < full.total)
    }

    /// R1 / BA-509: `computeFolderSizeFast`'s enumerator now passes `errorHandler: { _, _ in true }`,
    /// so an unreadable *nested* directory is skipped instead of aborting the whole walk — which used
    /// to undercount the folder's size while still presenting it as exact.
    private static func testUnreadableSubdirDoesNotAbortSizeWalk() async {
        guard getuid() != 0 else {
            report("Feature/DiskSpaceVisualizer", "SKIP (root): unreadable-subdir size-walk continuation", result: true)
            return
        }
        let fm = FileManager.default
        let root = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("diskviz_r1_\(UUID().uuidString)")
        let readableDir = root.appendingPathComponent("readable")
        let blockedDir = readableDir.appendingPathComponent("blocked")
        try? fm.createDirectory(at: blockedDir, withIntermediateDirectories: true)
        for index in 0 ..< 5 {
            try? Data(repeating: 0x41, count: 1000).write(to: readableDir.appendingPathComponent("f\(index).bin"))
        }
        try? Data(repeating: 0x42, count: 4096).write(to: blockedDir.appendingPathComponent("secret.bin"))
        try? fm.setAttributes([.posixPermissions: 0], ofItemAtPath: blockedDir.path)
        defer {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: blockedDir.path)
            try? fm.removeItem(at: root)
        }

        let reportResult = await ((try? DiskSpaceVisualizerService.calculateDiskUsage(for: root)) ?? DiskUsageReport(
            totalSize: 0, topItems: [], othersItem: nil))
        let readableItem = reportResult.topItems.first { $0.name == "readable" }
        report(
            "Feature/DiskSpaceVisualizer",
            "POS (R1): an unreadable nested directory doesn't abort the size walk — all 5 sibling files (5000 B) are still counted",
            result: readableItem?.size == 5000)
    }

    /// Covers the `contentsOfDirectory` failure branch: a folder URL that doesn't exist on disk (or
    /// can't be read) now throws (M20), so the sidebar shows an error state rather than "0 bytes".
    private static func testMissingFolderThrows() async {
        let missing = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        var threw = false
        do {
            _ = try await DiskSpaceVisualizerService.calculateDiskUsage(for: missing)
        } catch {
            threw = true
        }
        report("Feature/DiskSpaceVisualizer", "NEG: calculateDiskUsage for a nonexistent folder throws", result: threw)
    }

    /// Covers the `guard grandTotal > 0` branch: a folder that exists but contains nothing (or only
    /// zero-byte entries) also returns the zero-value report rather than dividing by zero for percentages.
    private static func testEmptyFolderReturnsEmptyReport() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let reportResult = await ((try? DiskSpaceVisualizerService.calculateDiskUsage(for: tempDir)) ?? DiskUsageReport(
            totalSize: 0,
            topItems: [],
            othersItem: nil))
        report(
            "Feature/DiskSpaceVisualizer",
            "NEG: calculateDiskUsage for an empty folder returns a zero-value report",
            result: reportResult.totalSize == 0 && reportResult.topItems.isEmpty && reportResult.othersItem == nil)
    }

    /// Covers `collectRawItems`'s `isDir` branch (calling `computeFolderSizeFast`) — a subfolder's
    /// size must be the recursive sum of its own contents, not zero/skipped.
    private static func testSubfolderSizeIsIncludedViaComputeFolderSizeFast() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let subfolder = tempDir.appendingPathComponent("subfolder")
        try? FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try? Data(repeating: 0x41, count: 2048).write(to: subfolder.appendingPathComponent("inner.bin"))

        let reportResult = await ((try? DiskSpaceVisualizerService.calculateDiskUsage(for: tempDir)) ?? DiskUsageReport(
            totalSize: 0,
            topItems: [],
            othersItem: nil))
        let subfolderItem = reportResult.topItems.first { $0.name == "subfolder" }
        report(
            "Feature/DiskSpaceVisualizer",
            "POS: a subfolder's size reflects the recursive size of its own contents",
            result: (subfolderItem?.isDirectory ?? false) && subfolderItem?.size == 2048)
    }

    /// Covers `buildReport`'s `othersItem` construction: with more than 10 entries, everything past
    /// the top 10 (by size) is aggregated into a single synthetic "Others" item.
    private static func testOthersBucketAggregatesItemsPastTop10() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 13 files of distinct sizes so sort order (largest first) is deterministic.
        for index in 0 ..< 13 {
            let size = (13 - index) * 100
            try? Data(repeating: 0x42, count: size).write(to: tempDir.appendingPathComponent("file\(index).bin"))
        }

        let reportResult = await ((try? DiskSpaceVisualizerService.calculateDiskUsage(for: tempDir)) ?? DiskUsageReport(
            totalSize: 0,
            topItems: [],
            othersItem: nil))
        report(
            "Feature/DiskSpaceVisualizer",
            "POS: with more than 10 entries, topItems is capped at 10 and the remainder is aggregated into othersItem",
            result: reportResult.topItems.count == 10 && reportResult.othersItem != nil)

        let othersSize = reportResult.othersItem?.size ?? 0
        // The 3 smallest files (sizes 100, 200, 300) fall past the top 10.
        report(
            "Feature/DiskSpaceVisualizer",
            "POS: othersItem's size is the sum of the 3 smallest files excluded from topItems",
            result: othersSize == 600)

        // The "Others" row's url is a placeholder that doesn't exist — it must be flagged synthetic
        // so the sidebar never navigates to it, while real top items are not flagged.
        report(
            "Feature/DiskSpaceVisualizer",
            "POS: othersItem is marked isSynthetic; real top items are not",
            result: (reportResult.othersItem?.isSynthetic ?? false) && reportResult.topItems.allSatisfy { !$0.isSynthetic })
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
