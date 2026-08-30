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

        let item = FileItem.load(url: tempFile, icon: NSWorkspace.shared.icon(forFile: tempFile.path))
        report("Model/FileItem", "POS: FileItem path matches temp file", result: item.url.path == tempFile.path)
        report("Model/FileItem", "POS: FileItem extension is txt", result: item.fileExtension == "txt")
        report("Model/FileItem", "POS: FileItem is not directory", result: !item.isDirectory)

        // POS: Identifiable.id mirrors the standardized url exactly (used by SwiftUI ForEach/List diffing).
        report("Model/FileItem", "POS: FileItem.id equals its url", result: item.id == item.url)

        // POS: Hashable conformance — two FileItem values built from the same file must hash identically
        // and be usable as Set/Dictionary keys, exercising hash(into:).
        let duplicateItem = FileItem.load(url: tempFile, icon: NSWorkspace.shared.icon(forFile: tempFile.path))
        let itemSet: Set<FileItem> = [item, duplicateItem]
        report(
            "Model/FileItem",
            "POS: FileItem.hash(into:) makes two equal items collapse into a single Set entry",
            result: itemSet.count == 1 && item.hashValue == duplicateItem.hashValue)

        let otherFile = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("item_test_other.txt")
        try? "Different Data".write(to: otherFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: otherFile) }
        let otherItem = FileItem.load(url: otherFile, icon: NSWorkspace.shared.icon(forFile: otherFile.path))
        report(
            "Model/FileItem",
            "NEG: FileItem.hash(into:) differing items are not forced into the same Set entry",
            result: Set([item, otherItem]).count == 2)

        testResizedCopyDoesNotMutateSharedIcon()
        testEqualityTracksAllICloudTransferFlags()
        testSupportsThumbnailIsPrecomputed()
    }

    /// L81: `supportsThumbnail` is computed once in `init` (from `isDirectory` + `fileExtension`) so an
    /// icon `body` reads a stored flag instead of re-running UTType classification every render.
    private static func testSupportsThumbnailIsPrecomputed() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        func item(_ name: String, isDir: Bool = false) -> FileItem {
            let url = tempDir.appendingPathComponent(name)
            if isDir {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                FileManager.default.createFile(atPath: url.path, contents: Data())
            }
            return FileItem.load(url: url, icon: NSWorkspace.shared.icon(forFile: url.path))
        }

        report("Model/FileItem", "POS: supportsThumbnail is true for an image (.png)", result: item("photo.png").supportsThumbnail)
        report("Model/FileItem", "POS: supportsThumbnail is true for a .pdf", result: item("doc.pdf").supportsThumbnail)
        report("Model/FileItem", "NEG: supportsThumbnail is false for a directory", result: !item("a-folder", isDir: true).supportsThumbnail)
        report("Model/FileItem", "NEG: supportsThumbnail is false for plain text (.txt)", result: !item("notes.txt").supportsThumbnail)
        report(
            "Model/FileItem",
            "POS: precomputed supportsThumbnail matches ThumbnailService.supportsThumbnail(item:)",
            result: item("photo.png").supportsThumbnail == ThumbnailService.supportsThumbnail(item: item("photo.png")))
    }

    /// A file that starts or stops downloading/uploading from iCloud must compare unequal to its
    /// earlier self, or the cloud-status badge never re-renders through SwiftUI's diff.
    private static func testEqualityTracksAllICloudTransferFlags() {
        func item(downloading: Bool = false, uploading: Bool = false, notDownloaded: Bool = false) -> FileItem {
            FileItem(
                url: URL(fileURLWithPath: "/tmp/cloud.txt"), name: "cloud.txt", isDirectory: false, size: 1,
                dateModified: Date(timeIntervalSinceReferenceDate: 0), dateCreated: Date(timeIntervalSinceReferenceDate: 0),
                dateAccessed: nil, ownerName: "--", groupName: "--", isHidden: false, fileExtension: "txt",
                icon: NSImage(), tags: [], tagColor: nil, isUbiquitous: true,
                isUbiquitousNotDownloaded: notDownloaded, isUbiquitousDownloading: downloading, isUbiquitousUploading: uploading)
        }
        report("Model/FileItem", "NEG: == distinguishes an item that started downloading from iCloud", result: item() != item(downloading: true))
        report("Model/FileItem", "NEG: == distinguishes an item that started uploading to iCloud", result: item() != item(uploading: true))
        report("Model/FileItem", "POS: == treats two items with identical iCloud flags as equal", result: item(downloading: true) == item(downloading: true))
    }

    /// `FileItem` sizes icons up to 512×512; the source may be a shared/cached system icon, so
    /// `resizedCopy(to:)` must produce a new image and leave the original's size untouched.
    private static func testResizedCopyDoesNotMutateSharedIcon() {
        let shared = NSWorkspace.shared.icon(forFile: "/")
        let originalSize = shared.size
        let resized = shared.resizedCopy(to: NSSize(width: 512, height: 512))
        report("Model/FileItem", "POS: resizedCopy returns a different image instance", result: resized !== shared)
        report("Model/FileItem", "POS: resizedCopy applies the requested size to the copy", result: resized.size == NSSize(width: 512, height: 512))
        report("Model/FileItem", "NEG: resizedCopy leaves the source (possibly shared) icon's size unchanged", result: shared.size == originalSize)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
