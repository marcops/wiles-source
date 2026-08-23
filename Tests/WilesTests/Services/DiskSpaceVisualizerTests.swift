import Foundation
@testable import Wiles

@MainActor
public struct DiskSpaceVisualizerTests {
    public static func run() async {
        await testBasicUsageAndNonExistentFolder()
        await testManyItemsGroupedUnderOthers()
        await testNestedSubdirectoryAggregation()

        await testEmptyDirectory()
        await testHiddenFilesSkipped()
        await testSortedDescendingBySize()
        await testExactlyTenItemsNoOthers()
        await testSymlinkHandling()
        await testPercentagesSumToTotal()
        await testPermissionDeniedSubdirectory()
        await testSingleLargeFileDominatesPercentage()
        await testDirectoryVsFileClassificationWithEqualZeroSizes()
        testDiskUsageItemIdentity()
    }

    // POS: Identifiable.id mirrors the item's own url exactly (used by SwiftUI ForEach/List diffing).
    private static func testDiskUsageItemIdentity() {
        let url = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("sample.bin")
        let item = DiskUsageItem(url: url, name: "sample.bin", size: 1024, percentage: 50.0, isDirectory: false, colorHue: 0.5)
        TestReporter.report("DiskSpaceVisualizer", "POS: DiskUsageItem.id equals its url", result: item.id == url)
    }

    private static func testBasicUsageAndNonExistentFolder() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let fileA = tempDir.appendingPathComponent("fileA.bin")
        let fileB = tempDir.appendingPathComponent("fileB.bin")
        let dataA = Data(repeating: 0, count: 1024)
        let dataB = Data(repeating: 0, count: 2048)
        try? dataA.write(to: fileA)
        try? dataB.write(to: fileB)

        // Positive: Disk Usage Report Calculation
        let report = await DiskSpaceVisualizerService.calculateDiskUsage(for: tempDir)
        let reportPos = report.totalSize >= 3072 && report.topItems.count >= 2
        TestReporter.report("DiskSpaceVisualizer", "POS: calculateDiskUsage returns accurate item sizes", result: reportPos)

        // Negative: Non-existent folder calculates zero size gracefully
        let fakeFolder = tempDir.appendingPathComponent("NonExistent")
        let emptyReport = await DiskSpaceVisualizerService.calculateDiskUsage(for: fakeFolder)
        TestReporter.report("DiskSpaceVisualizer", "NEG: Non-existent directory returns zero size report without crashing", result: emptyReport.totalSize == 0)

        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func testManyItemsGroupedUnderOthers() async {
        // POS: more than 10 items groups the smallest ones under "Others"
        let manyDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: manyDir, withIntermediateDirectories: true)
        for i in 0 ..< 13 {
            let itemFile = manyDir.appendingPathComponent("item\(i).bin")
            try? Data(repeating: 0, count: 1024 * (i + 1)).write(to: itemFile)
        }
        let manyReport = await DiskSpaceVisualizerService.calculateDiskUsage(for: manyDir)
        TestReporter.report(
            "DiskSpaceVisualizer",
            "POS: more than 10 items caps topItems at 10 and groups the rest into othersItem",
            result: manyReport.topItems.count == 10 && manyReport.othersItem != nil)
        try? FileManager.default.removeItem(at: manyDir)
    }

    private static func testNestedSubdirectoryAggregation() async {
        // POS: nested subdirectory size is aggregated recursively
        let nestedDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let subDir = nestedDir.appendingPathComponent("sub")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try? Data(repeating: 0, count: 4096).write(to: subDir.appendingPathComponent("nested.bin"))
        let nestedReport = await DiskSpaceVisualizerService.calculateDiskUsage(for: nestedDir)
        TestReporter.report(
            "DiskSpaceVisualizer", "POS: a subdirectory's size is computed recursively from its contents",
            result: nestedReport.topItems.first(where: { $0.name == "sub" })?.size == 4096)
        try? FileManager.default.removeItem(at: nestedDir)
    }

    // NEG: a subdirectory whose contents can't be enumerated (permission denied) doesn't crash the scan
    private static func testPermissionDeniedSubdirectory() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.appendingPathComponent("locked").path)
            try? FileManager.default.removeItem(at: dir)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let lockedDir = dir.appendingPathComponent("locked")
        try? FileManager.default.createDirectory(at: lockedDir, withIntermediateDirectories: true)
        try? Data(repeating: 0, count: 4096).write(to: lockedDir.appendingPathComponent("secret.bin"))
        try? FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: lockedDir.path)

        try? Data(repeating: 0, count: 1024).write(to: dir.appendingPathComponent("readable.bin"))

        let report = await DiskSpaceVisualizerService.calculateDiskUsage(for: dir)
        let lockedItem = report.topItems.first { $0.name == "locked" }
        TestReporter.report(
            "DiskSpaceVisualizer", "NEG: a permission-denied subdirectory is scanned as zero-size instead of crashing",
            result: lockedItem != nil && lockedItem?.size == 0 && report.totalSize == 1024)
    }

    // POS: a single very large file dominates the percentage breakdown near 100%
    private static func testSingleLargeFileDominatesPercentage() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try? Data(repeating: 0, count: 1_000_000).write(to: dir.appendingPathComponent("huge.bin"))
        try? Data(repeating: 0, count: 1).write(to: dir.appendingPathComponent("tiny.bin"))

        let report = await DiskSpaceVisualizerService.calculateDiskUsage(for: dir)
        let hugeItem = report.topItems.first { $0.name == "huge.bin" }
        TestReporter.report(
            "DiskSpaceVisualizer", "POS: a single very large file dominates the percentage breakdown near 100%",
            result: (hugeItem?.percentage ?? 0) > 99.9)
    }

    // NEG: an existing but empty directory yields zero size and no items (grandTotal guard)
    private static func testEmptyDirectory() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let report = await DiskSpaceVisualizerService.calculateDiskUsage(for: dir)
        TestReporter.report(
            "DiskSpaceVisualizer", "NEG: an existing empty directory returns zero total size and no top items",
            result: report.totalSize == 0 && report.topItems.isEmpty && report.othersItem == nil)
    }

    // NEG: dotfiles/hidden files are excluded from the scan (skipsHiddenFiles option)
    private static func testHiddenFilesSkipped() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try? Data(repeating: 0, count: 1024).write(to: dir.appendingPathComponent("visible.bin"))
        try? Data(repeating: 0, count: 1024 * 1024).write(to: dir.appendingPathComponent(".hidden.bin"))

        let report = await DiskSpaceVisualizerService.calculateDiskUsage(for: dir)
        let hasHidden = report.topItems.contains { $0.name == ".hidden.bin" }
        TestReporter.report(
            "DiskSpaceVisualizer", "NEG: hidden dotfiles are excluded from disk usage scan and total size",
            result: !hasHidden && report.totalSize == 1024)
    }

    // POS: topItems are sorted strictly descending by size
    private static func testSortedDescendingBySize() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try? Data(repeating: 0, count: 512).write(to: dir.appendingPathComponent("small.bin"))
        try? Data(repeating: 0, count: 8192).write(to: dir.appendingPathComponent("large.bin"))
        try? Data(repeating: 0, count: 2048).write(to: dir.appendingPathComponent("medium.bin"))

        let report = await DiskSpaceVisualizerService.calculateDiskUsage(for: dir)
        let sizes = report.topItems.map(\.size)
        let isDescending = sizes == sizes.sorted(by: >)
        TestReporter.report(
            "DiskSpaceVisualizer", "POS: topItems are sorted in strictly descending order by size",
            result: isDescending && sizes.first == 8192 && sizes.last == 512)
    }

    // POS: exactly 10 items produces no "Others" grouping (boundary condition, dropFirst(10) is empty)
    private static func testExactlyTenItemsNoOthers() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for i in 0 ..< 10 {
            try? Data(repeating: 0, count: 1024 * (i + 1)).write(to: dir.appendingPathComponent("f\(i).bin"))
        }

        let report = await DiskSpaceVisualizerService.calculateDiskUsage(for: dir)
        TestReporter.report(
            "DiskSpaceVisualizer", "POS: exactly 10 items produces a full topItems list with no othersItem",
            result: report.topItems.count == 10 && report.othersItem == nil)
    }

    // POS: a symlink to a file is treated as a file entry using fileExists' resolved size
    private static func testSymlinkHandling() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let target = dir.appendingPathComponent("target.bin")
        try? Data(repeating: 0, count: 4096).write(to: target)
        let link = dir.appendingPathComponent("link.bin")
        try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let report = await DiskSpaceVisualizerService.calculateDiskUsage(for: dir)
        let linkItem = report.topItems.first { $0.name == "link.bin" }
        TestReporter.report(
            "DiskSpaceVisualizer", "POS: a symlink entry appears in the report without crashing the scan",
            result: linkItem != nil)
    }

    // Regression coverage for the N+1 fileExists fix: collectRawItems now classifies each entry
    // via `itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory` instead of
    // `fm.fileExists(atPath:isDirectory:)`. An empty subdirectory and an empty file both report
    // size 0, so if the resourceValues-based check were ever wrong (e.g. defaulting everything to
    // "file" on failure), this is the case that would silently misclassify the directory — a size
    // comparison alone can't catch that, only isDirectory can.
    private static func testDirectoryVsFileClassificationWithEqualZeroSizes() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let emptySubdir = dir.appendingPathComponent("empty_dir")
        try? FileManager.default.createDirectory(at: emptySubdir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: dir.appendingPathComponent("empty_file.txt").path, contents: Data())
        // A non-empty file too, so the grand total isn't 0 and the scan actually returns items.
        try? Data(repeating: 0, count: 2048).write(to: dir.appendingPathComponent("anchor.bin"))

        let report = await DiskSpaceVisualizerService.calculateDiskUsage(for: dir)
        let dirItem = report.topItems.first { $0.name == "empty_dir" }
        let fileItem = report.topItems.first { $0.name == "empty_file.txt" }
        TestReporter.report(
            "DiskSpaceVisualizer", "POS: an empty subdirectory is classified isDirectory=true despite having zero size, same as a zero-byte file",
            result: dirItem?.isDirectory ?? false)
        TestReporter.report(
            "DiskSpaceVisualizer", "NEG: a zero-byte regular file is not misclassified as a directory",
            result: !(fileItem?.isDirectory ?? true))
    }

    // POS: percentages for top items plus others sum to ~100% of grand total
    private static func testPercentagesSumToTotal() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try? Data(repeating: 0, count: 1024).write(to: dir.appendingPathComponent("a.bin"))
        try? Data(repeating: 0, count: 3072).write(to: dir.appendingPathComponent("b.bin"))

        let report = await DiskSpaceVisualizerService.calculateDiskUsage(for: dir)
        let totalPct = report.topItems.reduce(0.0) { $0 + $1.percentage } + (report.othersItem?.percentage ?? 0.0)
        let aItem = report.topItems.first { $0.name == "a.bin" }
        let withinTolerance = abs(totalPct - 100.0) < 0.001
        let quarterPct = aItem.map { abs($0.percentage - 25.0) < 0.001 } ?? false
        TestReporter.report(
            "DiskSpaceVisualizer", "POS: item percentages are computed correctly and sum to 100% of grand total",
            result: withinTolerance && quarterPct)
    }
}
