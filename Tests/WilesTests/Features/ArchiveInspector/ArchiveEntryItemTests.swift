import Foundation
@testable import Wiles

@MainActor
public struct ArchiveEntryItemTests {
    public static func run() {
        testIdMirrorsPath()
        testDirectoryDetectionFromTrailingSlash()
        testNameExtractsLastPathComponentOnly()
        testNestedAndTopLevelPaths()
    }

    private static func testIdMirrorsPath() {
        let fileEntry = ArchiveEntryItem(path: "some/nested/file.txt")
        report("Feature/ArchiveEntryItem", "POS: id (Identifiable conformance) returns the entry's path", result: fileEntry.id == "some/nested/file.txt")

        let dirEntry = ArchiveEntryItem(path: "some/folder/")
        report("Feature/ArchiveEntryItem", "POS: id returns the entry's path even for directory entries", result: dirEntry.id == "some/folder/")
    }

    private static func testDirectoryDetectionFromTrailingSlash() {
        let directory = ArchiveEntryItem(path: "photos/")
        report("Feature/ArchiveEntryItem", "POS: a path ending in '/' is detected as a directory", result: directory.isDirectory == true)

        let file = ArchiveEntryItem(path: "photos/image.png")
        report("Feature/ArchiveEntryItem", "NEG: a path without a trailing '/' is not detected as a directory", result: file.isDirectory == false)

        let rootFile = ArchiveEntryItem(path: "readme.txt")
        report("Feature/ArchiveEntryItem", "NEG: a top-level file path is not detected as a directory", result: rootFile.isDirectory == false)
    }

    private static func testNameExtractsLastPathComponentOnly() {
        let nested = ArchiveEntryItem(path: "folder/subfolder/document.pdf")
        report("Feature/ArchiveEntryItem", "POS: name keeps only the last path component for a nested file", result: nested.name == "document.pdf")

        let topLevel = ArchiveEntryItem(path: "document.pdf")
        report("Feature/ArchiveEntryItem", "POS: name equals the full path when there is no nesting", result: topLevel.name == "document.pdf")

        let nestedDirectory = ArchiveEntryItem(path: "folder/subfolder/")
        report("Feature/ArchiveEntryItem", "POS: name strips the trailing slash for a nested directory entry", result: nestedDirectory.name == "subfolder")
    }

    private static func testNestedAndTopLevelPaths() {
        let deeplyNested = ArchiveEntryItem(path: "a/b/c/d/leaf.txt")
        report(
            "Feature/ArchiveEntryItem",
            "POS: deeply nested path preserves the full path while name resolves to only the leaf",
            result: deeplyNested.path == "a/b/c/d/leaf.txt" && deeplyNested.name == "leaf.txt" && deeplyNested.isDirectory == false)

        let topLevelDirectory = ArchiveEntryItem(path: "assets/")
        report(
            "Feature/ArchiveEntryItem",
            "POS: top-level directory entry is a directory and its name has the slash stripped",
            result: topLevelDirectory.isDirectory == true && topLevelDirectory.name == "assets")
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
