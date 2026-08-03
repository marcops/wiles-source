@testable import Wiles
import Foundation

@MainActor
public struct DiskSpaceVisualizerTests {
    public static func run() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
}
