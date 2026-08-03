@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct BatchRenameTests {
    public static func run() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let item1 = tempDir.appendingPathComponent("file_alpha.txt")
        let item2 = tempDir.appendingPathComponent("file_beta.txt")
        try? "Alpha".write(to: item1, atomically: true, encoding: .utf8)
        try? "Beta".write(to: item2, atomically: true, encoding: .utf8)

        let icon = NSWorkspace.shared.icon(forFile: item1.path)
        let fileItem1 = FileItem(url: item1, icon: icon)
        let fileItem2 = FileItem(url: item2, icon: icon)

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

        try? FileManager.default.removeItem(at: tempDir)
    }
}
