import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct FileItemTests {
    public static func run() {
        let tempFile = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("item_test.txt")
        try? "FileItem Test Data".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let item = FileItem(url: tempFile, icon: NSWorkspace.shared.icon(forFile: tempFile.path))
        report("Model/FileItem", "POS: FileItem path matches temp file", result: item.url.path == tempFile.path)
        report("Model/FileItem", "POS: FileItem extension is txt", result: item.fileExtension == "txt")
        report("Model/FileItem", "POS: FileItem is not directory", result: !item.isDirectory)

        // POS: Identifiable.id mirrors the standardized url exactly (used by SwiftUI ForEach/List diffing).
        report("Model/FileItem", "POS: FileItem.id equals its url", result: item.id == item.url)

        // POS: Hashable conformance — two FileItem values built from the same file must hash identically
        // and be usable as Set/Dictionary keys, exercising hash(into:).
        let duplicateItem = FileItem(url: tempFile, icon: NSWorkspace.shared.icon(forFile: tempFile.path))
        let itemSet: Set<FileItem> = [item, duplicateItem]
        report(
            "Model/FileItem",
            "POS: FileItem.hash(into:) makes two equal items collapse into a single Set entry",
            result: itemSet.count == 1 && item.hashValue == duplicateItem.hashValue)

        let otherFile = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("item_test_other.txt")
        try? "Different Data".write(to: otherFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: otherFile) }
        let otherItem = FileItem(url: otherFile, icon: NSWorkspace.shared.icon(forFile: otherFile.path))
        report(
            "Model/FileItem",
            "NEG: FileItem.hash(into:) differing items are not forced into the same Set entry",
            result: Set([item, otherItem]).count == 2)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
