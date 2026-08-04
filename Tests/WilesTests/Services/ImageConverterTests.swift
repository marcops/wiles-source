@testable import Wiles
import Foundation

@MainActor
public struct ImageConverterTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Negative: Converting non-image file throws error
        let textFile = tempDir.appendingPathComponent("not_an_image.png")
        try? "Plain Text".write(to: textFile, atomically: true, encoding: .utf8)

        var negPassed = false
        do {
            _ = try ImageConverterService.convertImage(at: textFile, targetFormat: .jpeg, preset: .original)
        } catch {
            negPassed = true
        }
        TestReporter.report("ImageConverter", "NEG: Converting non-image file throws error gracefully", result: negPassed)

        try? FileManager.default.removeItem(at: tempDir)
    }
}
