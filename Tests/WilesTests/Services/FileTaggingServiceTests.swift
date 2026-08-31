import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct FileTaggingServiceTests {
    public static func run() {
        testToggleTagAddsWhenAbsent()
        testToggleTagRemovesWhenPresent()
        testToggleTagUsesSnapshotForDirectionButDiskForContent()
        testToggleTagWithDuplicateURLsDoesNotCrash()
        testToggleTagReturnsErrorForMissingFile()
        testToggleTagAcrossMultipleURLsReturnsLastError()
        testClearAllTagsRemovesExistingTags()
        testClearAllTagsReturnsErrorForMissingFile()
        testCurrentTagsFallsBackToDirectDiskReadWhenNotInSnapshot()
        testToggleTagOnMixedSelectionAddsToAllThenRemovesFromAll()
    }

    private static func testToggleTagOnMixedSelectionAddsToAllThenRemovesFromAll() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let has = dir.appendingPathComponent("has.txt").standardizedFileURL
        let hasnt = dir.appendingPathComponent("hasnt.txt").standardizedFileURL
        try? "1".write(to: has, atomically: true, encoding: .utf8)
        try? "2".write(to: hasnt, atomically: true, encoding: .utf8)
        try? FileSystemService.setTags(for: has, tags: ["Blue"])

        _ = FileTaggingService.toggleTag("Blue", for: [has, hasnt], itemsSnapshot: [])
        let bothHave = FileTaggingService.currentTags(for: has, in: []).contains("Blue")
            && FileTaggingService.currentTags(for: hasnt, in: []).contains("Blue")
        report("POS: toggling a tag on a mixed selection adds it to every item (not a per-file flip)", result: bothHave)

        _ = FileTaggingService.toggleTag("Blue", for: [has, hasnt], itemsSnapshot: [])
        let neitherHas = !FileTaggingService.currentTags(for: has, in: []).contains("Blue")
            && !FileTaggingService.currentTags(for: hasnt, in: []).contains("Blue")
        report("POS: toggling again removes the tag from every item once the whole selection had it", result: neitherHas)
    }

    /// When the URL isn't in `itemsSnapshot`, `currentTags` reads `.tagNamesKey` straight off the
    /// file rather than building a whole `FileItem`.
    private static func testCurrentTagsFallsBackToDirectDiskReadWhenNotInSnapshot() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("direct-read.txt").standardizedFileURL
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        try? FileSystemService.setTags(for: file, tags: ["Green", "Important"])

        let fromDisk = FileTaggingService.currentTags(for: file, in: [])
        report("POS: currentTags reads tags from disk when the URL is absent from the snapshot", result: Set(fromDisk) == ["Green", "Important"])

        let missing = dir.appendingPathComponent("gone.txt")
        report(
            "NEG: currentTags returns [] for a URL with no backing file and no snapshot entry",
            result: FileTaggingService.currentTags(for: missing, in: []).isEmpty)
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
        let readBack = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)
        report("POS: toggleTag adds a tag not currently present, with no error", result: failureCount == 0 && readBack.tags.contains("Red"))
    }

    private static func testToggleTagRemovesWhenPresent() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("has_tag.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        try? FileSystemService.setTags(for: file, tags: ["Red"])

        let failureCount = FileTaggingService.toggleTag("Red", for: [file], itemsSnapshot: [])
        let readBack = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)
        report("NEG: toggleTag removes a tag already present, with no error", result: failureCount == 0 && !readBack.tags.contains("Red"))
    }

    /// MM-219: the snapshot decides add-vs-remove *direction*, but the tag set actually written is
    /// re-read from disk immediately before the write — so a tag added out-of-band (Finder, another
    /// app, another window) since the last directory load is preserved, not clobbered.
    private static func testToggleTagUsesSnapshotForDirectionButDiskForContent() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("external.txt").standardizedFileURL
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        try? FileSystemService.setTags(for: file, tags: ["Work"])
        let snapshotItem = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)

        // Another app adds "Red" on disk after the snapshot was taken.
        try? FileSystemService.setTags(for: file, tags: ["Work", "Red"])

        // Snapshot = ["Work"], missing "Important" ⇒ direction is "add". The write must start from
        // the current disk set ["Work", "Red"] and add "Important" — NOT from the stale snapshot,
        // which would drop "Red".
        let failureCount = FileTaggingService.toggleTag("Important", for: [file], itemsSnapshot: [snapshotItem])
        let readBack = Set(FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true).tags)
        report(
            "POS: toggleTag re-reads tags from disk before writing, so an externally-added tag is not clobbered (MM-219)",
            result: failureCount == 0 && readBack == ["Work", "Red", "Important"])
    }

    /// ML-085: `toggleTag` builds a `[URL: [String]]`; a caller passing a list with duplicates used
    /// to `fatalError` on `Dictionary(uniqueKeysWithValues:)`. It must now tolerate duplicates.
    private static func testToggleTagWithDuplicateURLsDoesNotCrash() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("dupe.txt").standardizedFileURL
        try? "x".write(to: file, atomically: true, encoding: .utf8)

        let failureCount = FileTaggingService.toggleTag("Red", for: [file, file, file], itemsSnapshot: [])
        let tagged = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true).tags.contains("Red")
        report(
            "POS: toggleTag with a duplicated URL in the list does not crash and still applies the tag",
            result: failureCount == 0 && tagged)
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
        let realFileTagged = FileItem.load(url: realFile, icon: NSWorkspace.shared.icon(forFile: realFile.path), fetchTags: true).tags.contains("Red")
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
        let readBack = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)
        report("POS: clearAllTags removes every tag with no error", result: failureCount == 0 && readBack.tags.isEmpty)
    }

    private static func testClearAllTagsReturnsErrorForMissingFile() {
        let missing = tempDir().appendingPathComponent("does_not_exist.txt")
        let failureCount = FileTaggingService.clearAllTags(for: [missing])
        report("NEG: clearAllTags returns a failure count for a URL with no backing file", result: failureCount > 0)
    }
}
