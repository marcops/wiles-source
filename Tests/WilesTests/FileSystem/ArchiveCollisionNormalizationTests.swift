import Foundation
import XCTest
@testable import Wiles

/// HH-291: a `.tar` made with `tar cf x.tar .` lists every entry prefixed with `./`, so the old
/// `entry.split("/").first` collision check saw only `.` as the top-level name, never matched an
/// on-disk name, and let `extractArchive` extract flat — `bsdtar` then overwrote the user's
/// same-named files with no Trash safety net. `topLevelEntryComponent` skips a leading `./` so the
/// collision check sees the real names again.
final class ArchiveCollisionNormalizationTests: XCTestCase {
    // MARK: - topLevelEntryComponent

    func testStripsLeadingDotSlash() {
        XCTAssertEqual(ArchiveService.topLevelEntryComponent("./file1"), "file1")
        XCTAssertEqual(ArchiveService.topLevelEntryComponent("./subdir/file2"), "subdir")
        XCTAssertEqual(ArchiveService.topLevelEntryComponent("file1"), "file1")
        XCTAssertEqual(ArchiveService.topLevelEntryComponent("subdir/file2"), "subdir")
    }

    func testHandlesBackslashSeparators() {
        XCTAssertEqual(ArchiveService.topLevelEntryComponent(".\\Documents\\a.txt"), "Documents")
        XCTAssertEqual(ArchiveService.topLevelEntryComponent("Documents\\a.txt"), "Documents")
    }

    func testNilForDotOnlyOrEmpty() {
        XCTAssertNil(ArchiveService.topLevelEntryComponent("."))
        XCTAssertNil(ArchiveService.topLevelEntryComponent("./"))
        XCTAssertNil(ArchiveService.topLevelEntryComponent(""))
        XCTAssertNil(ArchiveService.topLevelEntryComponent("/"))
    }

    // MARK: - entriesCollide (the actual regression)

    /// RED before the fix: `entries.split("/").first` yields `.` for every `./`-prefixed entry, so
    /// `topLevelEntryNames == {"."}`, disjoint from `{"documents"}` → returns false → flat extract →
    /// `Documents/` overwritten. GREEN after: `topLevelEntryComponent` yields `Documents`.
    func testTarCfDotArchiveCollidesWithExistingFolder() {
        let entries = ["./", "./Documents/", "./Documents/notes.txt", "./photo.jpg"]
        let onDisk: Set = ["documents", "music"]
        XCTAssertTrue(
            ArchiveService.entriesCollide(entries: entries, existingLowercasedNames: onDisk),
            "a `tar cf x.tar .` archive whose `./Documents/...` collides with an on-disk `Documents` must be detected")
    }

    func testTarCfDotArchiveNoCollisionWhenNamesFree() {
        let entries = ["./", "./fresh/", "./fresh/a.txt"]
        XCTAssertFalse(ArchiveService.entriesCollide(entries: entries, existingLowercasedNames: ["documents"]))
    }

    func testCaseInsensitiveMatch() {
        XCTAssertTrue(ArchiveService.entriesCollide(entries: ["./FOO/bar"], existingLowercasedNames: ["foo"]))
    }

    func testUnprefixedEntriesStillCollide() {
        XCTAssertTrue(ArchiveService.entriesCollide(entries: ["file1", "subdir/x"], existingLowercasedNames: ["file1"]))
    }

    func testNilEntriesNeverCollide() {
        XCTAssertFalse(ArchiveService.entriesCollide(entries: nil, existingLowercasedNames: ["anything"]))
    }

    func testDotOnlyEntriesAreIgnoredNotTreatedAsCollision() {
        XCTAssertFalse(ArchiveService.entriesCollide(entries: [".", "./"], existingLowercasedNames: ["."]))
    }
}
