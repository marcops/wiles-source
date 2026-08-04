@testable import Wiles
import Foundation

@MainActor
public struct FileShredderFeatureTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileToShred = tempDir.appendingPathComponent("shred.txt")
        try? "Sensitive Data".write(to: fileToShred, atomically: true, encoding: .utf8)

        try? await FileShredderService.shredFiles(urls: [fileToShred])
        report("Feature/FileShredder", "POS: FileShredderService removes file from disk", result: !FileManager.default.fileExists(atPath: fileToShred.path))

        try? await FileShredderService.shredFiles(urls: [fileToShred])
        report("Feature/FileShredder", "NEG: Shredding missing file does not crash", result: true)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
