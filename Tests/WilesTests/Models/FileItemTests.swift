@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct FileItemTests {
    public static func run() {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("item_test.txt")
        try? "FileItem Test Data".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let item = FileItem(url: tempFile, icon: NSWorkspace.shared.icon(forFile: tempFile.path))
        report("Model/FileItem", "POS: FileItem path matches temp file", result: item.url.path == tempFile.path)
        report("Model/FileItem", "POS: FileItem extension is txt", result: item.fileExtension == "txt")
        report("Model/FileItem", "POS: FileItem is not directory", result: !item.isDirectory)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
