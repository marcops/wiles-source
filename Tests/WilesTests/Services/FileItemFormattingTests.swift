import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct FileItemFormattingTests {
    public static func run() {
        testFormattedSizeForZeroByteFile()
        testFormattedSizeGrowsWithFileSize()
        testFormattedSizeForDirectory()
        testFormattedDatesForFreshFile()
        testFormattedDateFormatterCacheIsPerLanguageAndStable()
        testFormattedDateAccessedHandlesNil()
        testOwnerAndGroupNameResolution()
        testNeedsOwnerGroupFlagSkipsSyscall()
    }

    private static func makeFileItem(at url: URL) -> FileItem {
        FileItem.load(url: url, icon: NSImage(size: NSSize(width: 16, height: 16)))
    }

    private static func testFormattedSizeForZeroByteFile() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("empty.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data())
        let item = makeFileItem(at: file)

        report("FileItem.formattedSize", "POS: a 0-byte regular file produces a non-empty formatted size string", result: !item.formattedSize.isEmpty)
        report("FileItem.formattedSize", "NEG: a 0-byte regular file is not rendered as the directory placeholder \"--\"", result: item.formattedSize != "--")
    }

    private static func testFormattedSizeGrowsWithFileSize() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let smallFile = dir.appendingPathComponent("small.bin")
        FileManager.default.createFile(atPath: smallFile.path, contents: Data(repeating: 0x41, count: 500))
        let smallItem = makeFileItem(at: smallFile)

        let largeFile = dir.appendingPathComponent("large.bin")
        FileManager.default.createFile(atPath: largeFile.path, contents: Data(repeating: 0x42, count: 5_000_000))
        let largeItem = makeFileItem(at: largeFile)

        report("FileItem.formattedSize", "POS: a 500-byte file produces a non-empty formatted size string", result: !smallItem.formattedSize.isEmpty)
        report("FileItem.formattedSize", "POS: a 5,000,000-byte file produces a non-empty formatted size string", result: !largeItem.formattedSize.isEmpty)
        report(
            "FileItem.formattedSize",
            "POS: a several-megabyte file's formatted size differs from a 500-byte file's formatted size",
            result: smallItem.formattedSize != largeItem.formattedSize)
        report(
            "FileItem.formattedSize",
            "POS: a several-megabyte file's formatted size reports it in MB (larger unit than bytes)",
            result: largeItem.formattedSize.contains("MB"))
        report("FileItem.formattedSize", "NEG: a 500-byte file's formatted size is not reported in MB", result: !smallItem.formattedSize.contains("MB"))
    }

    private static func testFormattedSizeForDirectory() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let subdir = dir.appendingPathComponent("sub")
        try? FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let item = makeFileItem(at: subdir)

        report("FileItem.formattedSize", "POS: a directory's formattedSize is the \"--\" placeholder, not a byte count", result: item.formattedSize == "--")
        report("FileItem", "POS: a directory FileItem reports isDirectory true", result: item.isDirectory)
    }

    private static func testFormattedDatesForFreshFile() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("fresh.txt")
        try? "hello".write(to: file, atomically: true, encoding: .utf8)
        let item = makeFileItem(at: file)

        report("FileItem.formattedDate", "POS: formattedDate is non-empty for a freshly created file", result: !item.formattedDate(language: .system).isEmpty)
        report(
            "FileItem.formattedDateCreated",
            "POS: formattedDateCreated is non-empty for a freshly created file",
            result: !item.formattedDateCreated(language: .system).isEmpty)

        // FileItem formats dates from a locale-templated pattern with 2-digit fields (e.g.
        // "01/01/12 01:02") — a 2-digit year, not the 4-digit year a .medium style would produce.
        // Derive the expected token the same way rather than hardcoding either digit count, so this
        // stays correct regardless of locale.
        let shortFormatter = DateFormatter()
        shortFormatter.dateStyle = .short
        shortFormatter.timeStyle = .none
        let expectedYearToken = String(shortFormatter.string(from: Date()).suffix(2))
        report(
            "FileItem.formattedDate",
            "POS: formattedDate for a file just created now includes the current (short-style) year",
            result: item.formattedDate(language: .system).contains(expectedYearToken))
        report(
            "FileItem.formattedDateCreated",
            "POS: formattedDateCreated for a file just created now includes the current (short-style) year",
            result: item.formattedDateCreated(language: .system).contains(expectedYearToken))
        report(
            "FileItem.formattedDate",
            "NEG: formattedDate is not the raw placeholder \"--\" for a real file with a modification date",
            result: item.formattedDate(language: .system) != "--")
    }

    /// B4-6: the per-language `DateFormatter` cache (now `@MainActor`, lock-free) still returns a
    /// stable result per language and formats different languages differently.
    private static func testFormattedDateFormatterCacheIsPerLanguageAndStable() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("cache.txt")
        try? "hi".write(to: file, atomically: true, encoding: .utf8)
        let item = makeFileItem(at: file)

        let english1 = item.formattedDate(language: .english)
        let english2 = item.formattedDate(language: .english)
        report(
            "FileItem.formattedDate",
            "POS: repeated same-language formatting is stable",
            result: english1 == english2 && !english1.isEmpty)

        let japanese = item.formattedDate(language: .japanese)
        report(
            "FileItem.formattedDate",
            "POS: a different language produces its own formatted string",
            result: !japanese.isEmpty && item.formattedDate(language: .english) == english1)
    }

    private static func testFormattedDateAccessedHandlesNil() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("accessed.txt")
        try? "hello".write(to: file, atomically: true, encoding: .utf8)
        let item = makeFileItem(at: file)

        // dateAccessed is an Optional<Date> on FileItem; formattedDateAccessed must not
        // crash whether or not the filesystem actually supplies a content access date.
        report(
            "FileItem.formattedDateAccessed",
            "POS: formattedDateAccessed does not crash and produces a non-empty string either way",
            result: !item.formattedDateAccessed(language: .system).isEmpty)
        if item.dateAccessed == nil {
            report(
                "FileItem.formattedDateAccessed",
                "POS: formattedDateAccessed falls back to \"--\" when dateAccessed is nil",
                result: item.formattedDateAccessed(language: .system) == "--")
        } else {
            report(
                "FileItem.formattedDateAccessed",
                "POS: formattedDateAccessed is not the \"--\" placeholder when dateAccessed is present",
                result: item.formattedDateAccessed(language: .system) != "--")
        }
    }

    private static func testOwnerAndGroupNameResolution() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("owned.txt")
        try? "hello".write(to: file, atomically: true, encoding: .utf8)
        let item = makeFileItem(at: file)

        report("FileItem.ownerName", "POS: ownerName is resolved to a non-empty string for a real temp file", result: !item.ownerName.isEmpty)
        report("FileItem.groupName", "POS: groupName is resolved to a non-empty string for a real temp file", result: !item.groupName.isEmpty)
        report(
            "FileItem.ownerName",
            "NEG: ownerName is not the unresolved-owner placeholder \"--\" for a file we just created ourselves",
            result: item.ownerName != "--")
        report(
            "FileItem.groupName",
            "NEG: groupName is not the unresolved-owner placeholder \"--\" for a file we just created ourselves",
            result: item.groupName != "--")

        let currentUser = NSUserName()
        report(
            "FileItem.ownerName",
            "POS: ownerName matches the current process's account name for a file created by this process",
            result: item.ownerName == currentUser)
    }

    // Regression coverage for the N+1 owner/group syscall fix: FileItem.init gained a
    // `needsOwnerGroup: Bool = true` parameter. When false, it must skip the ownerAndGroup(atPath:)
    // syscall entirely and fall back to the "--" placeholders instead of resolving real values —
    // this is what lets bulk directory loads (which already fetch owner/group elsewhere) avoid a
    // per-file stat call. When true (or omitted, the default), real values must still be resolved,
    // proving the flag doesn't accidentally short-circuit the normal path.
    private static func testNeedsOwnerGroupFlagSkipsSyscall() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("needs_owner_group.txt")
        try? "hello".write(to: file, atomically: true, encoding: .utf8)

        let skippedItem = FileItem.load(url: file, icon: NSImage(size: NSSize(width: 16, height: 16)), needsOwnerGroup: false)
        report(
            "FileItem.needsOwnerGroup", "POS: needsOwnerGroup: false sets ownerName to the \"--\" placeholder instead of resolving it",
            result: skippedItem.ownerName == "--")
        report(
            "FileItem.needsOwnerGroup", "POS: needsOwnerGroup: false sets groupName to the \"--\" placeholder instead of resolving it",
            result: skippedItem.groupName == "--")

        let resolvedItem = FileItem.load(url: file, icon: NSImage(size: NSSize(width: 16, height: 16)), needsOwnerGroup: true)
        let currentUser = NSUserName()
        report(
            "FileItem.needsOwnerGroup", "NEG: needsOwnerGroup: true still resolves ownerName to a real (non-placeholder) value",
            result: resolvedItem.ownerName != "--" && resolvedItem.ownerName == currentUser)
        report(
            "FileItem.needsOwnerGroup", "NEG: needsOwnerGroup: true still resolves groupName to a real (non-placeholder) value",
            result: resolvedItem.groupName != "--" && !resolvedItem.groupName.isEmpty)

        let defaultedItem = FileItem.load(url: file, icon: NSImage(size: NSSize(width: 16, height: 16)))
        report(
            "FileItem.needsOwnerGroup", "POS: omitting needsOwnerGroup defaults to true and still resolves a real ownerName",
            result: defaultedItem.ownerName == currentUser)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
