import AppKit
import Foundation
@testable import Wiles

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

        testInvalidRegexPatternThrowsInsteadOfSilentlyNoOpingRename()
    }

    /// Bug: performBatchRename used to fall through NSRegularExpression's `try?` failure by
    /// leaving `newBaseName = baseName` - an invalid user-typed regex pattern silently pretended
    /// no rename was requested instead of telling the user their pattern was invalid. This proves
    /// performBatchRename now throws for an invalid regex pattern, and that it aborts before
    /// touching the filesystem (the file keeps its original name) rather than silently no-op'ing.
    private static func testInvalidRegexPatternThrowsInsteadOfSilentlyNoOpingRename() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("file_gamma.txt")
        try? "gamma".write(to: file, atomically: true, encoding: .utf8)
        let item = FileItem(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))

        let invalidRegexMode = BatchRenameMode.regex(pattern: "[", template: "X")

        var didThrow = false
        do {
            _ = try BatchRenameService.performBatchRename(items: [item], mode: invalidRegexMode)
        } catch {
            didThrow = true
        }

        report(
            "Feature/BatchRename",
            "NEG: performBatchRename throws instead of silently no-oping for an invalid regex pattern",
            result: didThrow)
        report(
            "Feature/BatchRename",
            "NEG: file keeps its original name when the regex pattern is invalid",
            result: FileManager.default.fileExists(atPath: file.path))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
