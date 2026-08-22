import AppKit
import Foundation
@testable import Wiles

/// A few defensive fallback branches in `FileItem` are intentionally left uncovered — each requires
/// a real file/volume state that couldn't be reliably forced without mocking `FileManager`/`URL`
/// resource values, which `FileItem` has no injectable seam for:
/// - `resolveHighResIcon`'s `(resolvedIcon.copy() as? NSImage) ?? resolvedIcon` fallback: `NSImage.copy()`
///   was not observed to ever fail the `as? NSImage` cast in practice.
/// - `ownerAndGroup`'s `(attrs[.ownerAccountName] as? String) ?? "--"` /
///   `(attrs[.groupOwnerAccountName] as? String) ?? "--"` fallbacks: a real temp file's
///   `attributesOfItem(atPath:)` always includes both keys as `String` on this platform.
/// - `formattedDateAccessed`'s `guard let date = dateAccessed else { return "--" }`: `.contentAccessDateKey`
///   was verified (regular files, directories, `/dev/null`) to always resolve on macOS — see
///   `FileItemFormattingTests.testFormattedDateAccessedHandlesNil()`, which already handles either
///   outcome defensively since this is genuinely environment-dependent.
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
