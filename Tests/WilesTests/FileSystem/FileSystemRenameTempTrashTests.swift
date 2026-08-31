import Foundation
import XCTest
@testable import Wiles

/// Covers `FileSystemService.sweepStaleRenameTemps` (a case-only rename that crashed between its two
/// moves must not strand its `.wiles-rename-*` temp forever) and `resolveTrashedItemURL` (a
/// `moveToTrash` that can't read `resultingItemURL` must not hand back the now-gone source path,
/// which would make a `.trash` undo fail with `itemAlreadyInDestination`).
final class FileSystemRenameTempTrashTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    @discardableResult
    private func makeFile(_ name: String, in dir: URL, ageSeconds: TimeInterval? = nil) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data().write(to: url)
        if let ageSeconds {
            try FileManager.default.setAttributes(
                [.modificationDate: Date().addingTimeInterval(-ageSeconds)], ofItemAtPath: url.path)
        }
        return url
    }

    // MARK: - Stale rename-temp sweep

    func testSweepRemovesStaleRenameTempButKeepsFreshOneAndUnrelatedFiles() throws {
        let tempDir = try makeTempDir()
        let stale = try makeFile("\(FileSystemService.renameTempPrefix)stranded", in: tempDir, ageSeconds: 120)
        let fresh = try makeFile("\(FileSystemService.renameTempPrefix)inflight", in: tempDir)
        let dotfile = try makeFile(".DS_Store", in: tempDir, ageSeconds: 999)
        let realFile = try makeFile("Report.txt", in: tempDir, ageSeconds: 999)

        FileSystemService.sweepStaleRenameTemps(in: tempDir, olderThan: 60)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path), "a minutes-old rename temp is a crash leftover")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path), "a just-created rename temp belongs to a live rename")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dotfile.path), "only the rename-temp prefix is swept")
        XCTAssertTrue(FileManager.default.fileExists(atPath: realFile.path))
    }

    func testSweepOnMissingDirectoryIsANoOp() throws {
        let tempDir = try makeTempDir()
        FileSystemService.sweepStaleRenameTemps(in: tempDir.appendingPathComponent("nope"))
    }

    func testCaseOnlyRenameSweepsAPriorStrandedTemp() async throws {
        let tempDir = try makeTempDir()
        let stranded = try makeFile("\(FileSystemService.renameTempPrefix)crashed", in: tempDir, ageSeconds: 300)
        let file = try makeFile("readme", in: tempDir)

        _ = try await FileSystemService.renameItem(at: file, newName: "README")

        XCTAssertFalse(FileManager.default.fileExists(atPath: stranded.path), "a case-only rename GCs a prior crashed temp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("README").path))
    }

    // MARK: - Reconstructed trashed URL

    func testResolveTrashedItemURLReturnsExistingItemInTrashDir() throws {
        let tempDir = try makeTempDir()
        let landed = try makeFile("moved.txt", in: tempDir)
        let resolved = FileSystemService.resolveTrashedItemURL(named: "moved.txt", in: tempDir)
        XCTAssertEqual(resolved.standardizedFileURL, landed.standardizedFileURL)
    }

    /// MM-150: `trashItem` renames on a name collision inside the Trash, so a lookup of the exact
    /// original name misses. The resolver must find the collision-renamed sibling (newest wins) and
    /// hand back a real, existing path so the `.trash` undo works — not a false failure.
    func testResolveTrashedItemURLFindsCollisionRenamedSibling() throws {
        let tempDir = try makeTempDir()
        let older = try makeFile("note 2.txt", in: tempDir, ageSeconds: 120)
        let newer = try makeFile("note 10-30-45.txt", in: tempDir)
        _ = older

        let resolved = FileSystemService.resolveTrashedItemURL(named: "note.txt", in: tempDir)

        XCTAssertEqual(resolved.standardizedFileURL, newer.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.path))
    }

    /// A different extension is not a match even if the stem looks similar.
    func testResolveTrashedItemURLIgnoresDifferentExtension() throws {
        let tempDir = try makeTempDir()
        _ = try makeFile("note 2.md", in: tempDir)
        let resolved = FileSystemService.resolveTrashedItemURL(named: "note.txt", in: tempDir)
        XCTAssertEqual(resolved.standardizedFileURL, tempDir.appendingPathComponent("note.txt").standardizedFileURL)
    }

    /// MM-150: when nothing can be found, return the expected path rather than throwing — the item
    /// is in the Trash regardless, and a false "couldn't move to Trash" alert + lost undo is worse.
    func testResolveTrashedItemURLReturnsExpectedPathWhenNothingFound() throws {
        let tempDir = try makeTempDir()
        let resolved = FileSystemService.resolveTrashedItemURL(named: "ghost.txt", in: tempDir)
        XCTAssertEqual(resolved.standardizedFileURL, tempDir.appendingPathComponent("ghost.txt").standardizedFileURL)
    }
}
