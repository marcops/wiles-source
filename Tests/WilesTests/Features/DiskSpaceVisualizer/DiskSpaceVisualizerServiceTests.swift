@testable import Wiles
import Foundation

@MainActor
public struct DiskSpaceVisualizerFeatureTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("data.bin")
        try? Data(repeating: 0x41, count: 1024).write(to: file)

        let reportResult = await DiskSpaceVisualizerService.calculateDiskUsage(for: tempDir)
        report("Feature/DiskSpaceVisualizer", "POS: Disk space report calculates totalSize > 0", result: reportResult.totalSize >= 1024)
        report("Feature/DiskSpaceVisualizer", "POS: Report contains topItems", result: !reportResult.topItems.isEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
