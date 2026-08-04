@testable import Wiles
import Foundation

@MainActor
public struct DiskSpaceVisualizerTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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

        // POS: more than 10 items groups the smallest ones under "Others"
        let manyDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: manyDir, withIntermediateDirectories: true)
        for i in 0..<13 {
            let f = manyDir.appendingPathComponent("item\(i).bin")
            try? Data(repeating: 0, count: 1024 * (i + 1)).write(to: f)
        }
        let manyReport = await DiskSpaceVisualizerService.calculateDiskUsage(for: manyDir)
        TestReporter.report("DiskSpaceVisualizer", "POS: more than 10 items caps topItems at 10 and groups the rest into othersItem", result: manyReport.topItems.count == 10 && manyReport.othersItem != nil)
        try? FileManager.default.removeItem(at: manyDir)

        // POS: nested subdirectory size is aggregated recursively
        let nestedDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let subDir = nestedDir.appendingPathComponent("sub")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try? Data(repeating: 0, count: 4096).write(to: subDir.appendingPathComponent("nested.bin"))
        let nestedReport = await DiskSpaceVisualizerService.calculateDiskUsage(for: nestedDir)
        TestReporter.report(
            "DiskSpaceVisualizer", "POS: a subdirectory's size is computed recursively from its contents",
            result: nestedReport.topItems.first(where: { $0.name == "sub" })?.size == 4096
        )
        try? FileManager.default.removeItem(at: nestedDir)
    }
}
