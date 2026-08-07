@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct BatchRenameFeatureTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("file_a.txt")
        try? "test".write(to: file1, atomically: true, encoding: .utf8)
        let item1 = FileItem(url: file1, icon: NSWorkspace.shared.icon(forFile: file1.path))

        let prefixMode = BatchRenameMode.addPrefixSuffix(prefix: "PRE_", suffix: "_POST")
        let previews = BatchRenameService.previewNewNames(items: [item1], mode: prefixMode)
        report("Feature/BatchRename", "POS: Prefix and suffix added correctly", result: previews.first?.newName == "PRE_file_a_POST.txt")

        let regexMode = BatchRenameMode.regex(pattern: "file_(.*)", template: "document_$1")
        let regexPreviews = BatchRenameService.previewNewNames(items: [item1], mode: regexMode)
        report("Feature/BatchRename", "POS: Regex replace template works", result: regexPreviews.first?.newName == "document_a.txt")
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
