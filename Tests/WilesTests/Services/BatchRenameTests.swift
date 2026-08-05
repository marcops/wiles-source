@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct BatchRenameTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let item1 = tempDir.appendingPathComponent("file_alpha.txt")
        let item2 = tempDir.appendingPathComponent("file_beta.txt")
        try? "Alpha".write(to: item1, atomically: true, encoding: .utf8)
        try? "Beta".write(to: item2, atomically: true, encoding: .utf8)

        let icon = NSWorkspace.shared.icon(forFile: item1.path)
        let fileItem1 = FileItem(url: item1, icon: icon)
        let fileItem2 = FileItem(url: item2, icon: icon)

        testFindReplaceAndPreviewModes(tempDir: tempDir, fileItem1: fileItem1, fileItem2: fileItem2)
        testRegexModesAndDirectoryItems(tempDir: tempDir, fileItem1: fileItem1)

        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func testFindReplaceAndPreviewModes(tempDir: URL, fileItem1: FileItem, fileItem2: FileItem) {
        // Positive: Find & Replace Batch Rename
        let batchResult = try? BatchRenameService.performBatchRename(
            items: [fileItem1, fileItem2],
            mode: .replace(find: "file_", replaceWith: "doc_")
        )
        let batchPos = (batchResult?.count == 2) && FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("doc_alpha.txt").path)
        TestReporter.report("BatchRename", "POS: performBatchRename (.replace)", result: batchPos)

        // Negative: Empty Find String (No Change)
        let docAlphaURL = tempDir.appendingPathComponent("doc_alpha.txt")
        let currentItem1 = FileItem(url: docAlphaURL, icon: NSWorkspace.shared.icon(forFile: docAlphaURL.path))
        let negBatchResult = try? BatchRenameService.performBatchRename(
            items: [currentItem1],
            mode: .replace(find: "", replaceWith: "prefix_")
        )
        TestReporter.report("BatchRename", "NEG: performBatchRename with empty pattern returns unchanged URLs", result: negBatchResult?.first?.lastPathComponent == "doc_alpha.txt")

        // POS: addPrefixSuffix mode
        let prefixSuffixPreview = BatchRenameService.previewNewNames(items: [fileItem1], mode: .addPrefixSuffix(prefix: "PRE_", suffix: "_POST"))
        TestReporter.report("BatchRename", "POS: previewNewNames(.addPrefixSuffix) wraps the base name", result: prefixSuffixPreview.first?.newName == "PRE_file_alpha_POST.txt")

        // POS: sequenceNumber mode increments per item with zero-padding
        let seqPreview = BatchRenameService.previewNewNames(items: [fileItem1, fileItem2], mode: .sequenceNumber(prefix: "img", startNumber: 1, paddingDigits: 3))
        TestReporter.report(
            "BatchRename", "POS: previewNewNames(.sequenceNumber) increments and zero-pads across items",
            result: seqPreview.map { $0.newName } == ["img_001.txt", "img_002.txt"]
        )

        // POS: sequenceNumber mode with empty prefix omits the leading underscore
        let seqNoPrefixPreview = BatchRenameService.previewNewNames(items: [fileItem1], mode: .sequenceNumber(prefix: "", startNumber: 5, paddingDigits: 2))
        TestReporter.report(
            "BatchRename",
            "POS: previewNewNames(.sequenceNumber) with empty prefix has no leading underscore",
            result: seqNoPrefixPreview.first?.newName == "05.txt"
        )
    }

    private static func testRegexModesAndDirectoryItems(tempDir: URL, fileItem1: FileItem) {
        // POS: regex mode with a valid pattern
        let regexPreview = BatchRenameService.previewNewNames(items: [fileItem1], mode: .regex(pattern: "alpha", template: "ALPHA"))
        TestReporter.report("BatchRename", "POS: previewNewNames(.regex) applies a valid pattern substitution", result: regexPreview.first?.newName == "file_ALPHA.txt")

        // NEG: regex mode with an empty pattern leaves the name unchanged
        let regexEmptyPreview = BatchRenameService.previewNewNames(items: [fileItem1], mode: .regex(pattern: "", template: "X"))
        TestReporter.report(
            "BatchRename",
            "NEG: previewNewNames(.regex) with an empty pattern leaves the base name unchanged",
            result: regexEmptyPreview.first?.newName == "file_alpha.txt"
        )

        // NEG: regex mode with an invalid pattern falls back to the original base name instead of crashing
        let regexInvalidPreview = BatchRenameService.previewNewNames(items: [fileItem1], mode: .regex(pattern: "[", template: "X"))
        TestReporter.report(
            "BatchRename",
            "NEG: previewNewNames(.regex) with an invalid pattern falls back to the original name",
            result: regexInvalidPreview.first?.newName == "file_alpha.txt"
        )

        // POS: directory items are renamed without an extension being appended
        let dirURL = tempDir.appendingPathComponent("a_folder")
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let dirItem = FileItem(url: dirURL, icon: NSWorkspace.shared.icon(forFile: dirURL.path))
        let dirPreview = BatchRenameService.previewNewNames(items: [dirItem], mode: .addPrefixSuffix(prefix: "new_", suffix: ""))
        TestReporter.report("BatchRename", "POS: previewNewNames on a directory item does not append a file extension", result: dirPreview.first?.newName == "new_a_folder")
    }
}
