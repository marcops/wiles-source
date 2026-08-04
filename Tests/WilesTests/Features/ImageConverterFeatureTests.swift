@testable import Wiles
import Foundation

@MainActor
public struct ImageConverterFeatureTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let missingSource = tempDir.appendingPathComponent("missing.png")
        let result = try? ImageConverterService.convertImage(at: missingSource, targetFormat: .jpeg, preset: .original, quality: 0.8)
        report("Feature/ImageConverter", "NEG: Converting nonexistent image throws error", result: result == nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
