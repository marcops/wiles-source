import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct FileTaggingServiceTests {
    public static func run() {
        testToggleTagAddsWhenAbsent()
        testToggleTagRemovesWhenPresent()
        testToggleTagUsesItemsSnapshotOverDiskState()
        testToggleTagReturnsErrorForMissingFile()
        testToggleTagAcrossMultipleURLsReturnsLastError()
        testClearAllTagsRemovesExistingTags()
        testClearAllTagsReturnsErrorForMissingFile()
    }

    private static func tempDir() -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func report(_ name: String, result: Bool) {
        TestReporter.report("Service/FileTagging", name, result: result)
    }

    private static func testToggleTagAddsWhenAbsent() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("no_tags.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)

        let failureCount = FileTaggingService.toggleTag("Red", for: [file], itemsSnapshot: [])
        let readBack = FileItem(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)
        report("POS: toggleTag adds a tag not currently present, with no error", result: failureCount == 0 && readBack.tags.contains("Red"))
    }

    private static func testToggleTagRemovesWhenPresent() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("has_tag.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        try? FileSystemService.setTags(for: file, tags: ["Red"])

        let failureCount = FileTaggingService.toggleTag("Red", for: [file], itemsSnapshot: [])
        let readBack = FileItem(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)
        report("NEG: toggleTag removes a tag already present, with no error", result: failureCount == 0 && !readBack.tags.contains("Red"))
    }

    /// Proves `currentItem` comes from `itemsSnapshot` (when the URL is present there) rather than
    /// always re-reading tags from disk — the snapshot's in-memory tags are stale on purpose here.
    private static func testToggleTagUsesItemsSnapshotOverDiskState() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Standardized up front so it matches FileItem's own `url.standardizedFileURL` storage
        // exactly — toggleTag looks up `itemsSnapshot` by raw `==` on `url`, and /tmp resolving
        // through a symlink would otherwise make the snapshot lookup silently miss.
        let file = dir.appendingPathComponent("snapshot.txt").standardizedFileURL
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        try? FileSystemService.setTags(for: file, tags: ["Blue"])
        let snapshotItem = FileItem(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)

        // Disk now disagrees with the snapshot: snapshot says ["Blue"], disk says ["Green"].
        try? FileSystemService.setTags(for: file, tags: ["Green"])

        // toggleTag replaces the full tag set wholesale (`setTags(tags: newTags)`), it doesn't merge.
        // Starting from the snapshot's ["Blue"] and toggling "Blue" off yields an empty set: neither
        // "Blue" (removed) nor "Green" (never part of the snapshot-derived set) survives. Had toggleTag
        // instead re-read fresh from disk, it would have started from ["Green"], found "Blue" absent,
        // and added it — leaving both "Green" and "Blue" present. Asserting the tag set ends up empty
        // is therefore what actually distinguishes "used the snapshot" from "read fresh from disk".
        let failureCount = FileTaggingService.toggleTag("Blue", for: [file], itemsSnapshot: [snapshotItem])
        let readBack = FileItem(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)
        report(
            "POS: toggleTag computes the new tag set from itemsSnapshot's tags, not a fresh disk read",
            result: failureCount == 0 && readBack.tags.isEmpty)
    }

    private static func testToggleTagReturnsErrorForMissingFile() {
        let missing = tempDir().appendingPathComponent("does_not_exist.txt")
        let failureCount = FileTaggingService.toggleTag("Red", for: [missing], itemsSnapshot: [])
        report("NEG: toggleTag returns a failure count for a URL with no backing file", result: failureCount > 0)
    }

    private static func testToggleTagAcrossMultipleURLsReturnsLastError() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let realFile = dir.appendingPathComponent("real.txt")
        try? "x".write(to: realFile, atomically: true, encoding: .utf8)
        let missingFile = dir.appendingPathComponent("missing.txt")

        let failureCount = FileTaggingService.toggleTag("Red", for: [realFile, missingFile], itemsSnapshot: [])
        let realFileTagged = FileItem(url: realFile, icon: NSWorkspace.shared.icon(forFile: realFile.path), fetchTags: true).tags.contains("Red")
        report(
            "POS: toggleTag keeps processing every URL and reports the failure count even after an earlier success",
            result: failureCount == 1 && realFileTagged)
    }

    private static func testClearAllTagsRemovesExistingTags() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("tagged.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        try? FileSystemService.setTags(for: file, tags: ["Red", "Important"])

        let failureCount = FileTaggingService.clearAllTags(for: [file])
        let readBack = FileItem(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)
        report("POS: clearAllTags removes every tag with no error", result: failureCount == 0 && readBack.tags.isEmpty)
    }

    private static func testClearAllTagsReturnsErrorForMissingFile() {
        let missing = tempDir().appendingPathComponent("does_not_exist.txt")
        let failureCount = FileTaggingService.clearAllTags(for: [missing])
        report("NEG: clearAllTags returns a failure count for a URL with no backing file", result: failureCount > 0)
    }
}
