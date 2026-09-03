import Foundation
import XCTest
@testable import Wiles

/// CH-190: a `.replace` move stages the displaced file aside as `.wiles-replace-<UUID>`, then sends
/// it to the Trash. On a volume with no Trash support (`SMB`/`AFP` share, `FAT`/`exFAT` drive)
/// `trashItem` throws — the old code then left the displaced file under the `.wiles-replace-` prefix
/// and handed that path back as the `.trash` undo target. `sweepStaleRenameTemps` (run by the next
/// replace-move / case-only rename in that folder) then permanently deleted it, and the undo failed.
/// The fix renames it to a visible, non-swept `<name> (replaced).<ext>` instead.
final class FileSystemReplaceRecoveryTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    @discardableResult
    private func makeFile(_ name: String, in dir: URL, bytes: [UInt8] = [1, 2, 3], ageSeconds: TimeInterval? = nil) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        if let ageSeconds {
            try FileManager.default.setAttributes(
                [.modificationDate: Date().addingTimeInterval(-ageSeconds)], ofItemAtPath: url.path)
        }
        return url
    }

    // MARK: - displacedRecoveryName

    func testDisplacedRecoveryNameInsertsMarkerBeforeExtension() {
        XCTAssertEqual(FileSystemService.displacedRecoveryName(for: "note.txt", isDirectory: false), "note (replaced).txt")
    }

    func testDisplacedRecoveryNameWithNoExtensionAppendsMarker() {
        XCTAssertEqual(FileSystemService.displacedRecoveryName(for: "README", isDirectory: false), "README (replaced)")
    }

    func testDisplacedRecoveryNameForDirectoryKeepsFullNameNoSplit() {
        XCTAssertEqual(FileSystemService.displacedRecoveryName(for: "My.Files", isDirectory: true), "My.Files (replaced)")
    }

    // MARK: - recoverUntrashableDisplacedFile

    func testRecoverMovesStagedFileToVisibleNonSweptName() throws {
        let dir = try makeTempDir()
        let staged = try makeFile("\(FileSystemService.replaceTempPrefix)\(UUID().uuidString)", in: dir, bytes: [9, 9, 9])

        let recovered = FileSystemService.recoverUntrashableDisplacedFile(
            stagedAt: staged, originalName: "photo.jpg", in: dir)

        XCTAssertEqual(recovered.standardizedFileURL, dir.appendingPathComponent("photo (replaced).jpg").standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovered.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path), "the staged temp is moved, not left behind")
        XCTAssertFalse(
            recovered.lastPathComponent.hasPrefix(FileSystemService.replaceTempPrefix),
            "recovered name must not carry the swept prefix")
        XCTAssertEqual(try Data(contentsOf: recovered), Data([9, 9, 9]), "the displaced file's bytes are preserved")
    }

    func testRecoverUniquifiesWhenTheVisibleNameIsAlreadyTaken() throws {
        let dir = try makeTempDir()
        try makeFile("doc (replaced).pdf", in: dir)
        let staged = try makeFile("\(FileSystemService.replaceTempPrefix)\(UUID().uuidString)", in: dir)

        let recovered = FileSystemService.recoverUntrashableDisplacedFile(
            stagedAt: staged, originalName: "doc.pdf", in: dir)

        XCTAssertEqual(recovered.standardizedFileURL, dir.appendingPathComponent("doc (replaced) 2.pdf").standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovered.path))
    }

    /// The core regression: a recovered displaced file must survive the sweep that used to delete it.
    func testRecoveredDisplacedFileSurvivesTheStaleRenameTempSweep() throws {
        let dir = try makeTempDir()
        let staged = try makeFile("\(FileSystemService.replaceTempPrefix)\(UUID().uuidString)", in: dir, ageSeconds: 300)

        let recovered = FileSystemService.recoverUntrashableDisplacedFile(
            stagedAt: staged, originalName: "keepme.txt", in: dir)

        // Age the recovered file too, then run the sweep a later replace/case-rename would run.
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-300)], ofItemAtPath: recovered.path)
        FileSystemService.sweepStaleRenameTemps(in: dir, olderThan: 60)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: recovered.path),
            "CH-190: the displaced file is under a visible name now, so the sweep leaves it alone")
    }

    /// End-to-end through the real `moveItemReplacing` on the boot-volume temp dir (which supports
    /// Trash): the incoming file wins the destination and a real recoverable location is reported —
    /// i.e. the new `catch` path didn't disturb the happy path. Skipped on a volume without Trash
    /// support (the `catch` path itself is covered by the pure `recoverUntrashableDisplacedFile`
    /// tests above).
    func testMoveItemReplacingHappyPathStillReportsARealRecoverableLocation() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("incoming.txt")
        try Data([7, 7]).write(to: source)
        let subdir = dir.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        try Data([1, 1, 1]).write(to: subdir.appendingPathComponent("incoming.txt"))

        let outcome: (destination: URL, displacedTrashedURL: URL?)
        do {
            outcome = try await FileSystemService.moveItemReplacing(at: source, toFolder: subdir)
        } catch {
            throw XCTSkip("moveItemReplacing failed on this volume (likely no Trash support): \(error)")
        }

        XCTAssertEqual(outcome.destination.standardizedFileURL, subdir.appendingPathComponent("incoming.txt").standardizedFileURL)
        XCTAssertEqual(try Data(contentsOf: outcome.destination), Data([7, 7]), "the incoming file won the destination")
        let recoverable = try XCTUnwrap(outcome.displacedTrashedURL, "a recoverable location must be reported, not nil")

        // CH-190's invariant: the displaced file must not be left at `targetFolder/.wiles-replace-*`
        // — that exact combination is what `sweepStaleRenameTemps` (which only runs in `targetFolder`)
        // permanently deletes. In the Trash under that name is fine (the sweep never looks there).
        let strandedUnderTheSweep =
            recoverable.deletingLastPathComponent().standardizedFileURL == subdir.standardizedFileURL
                && recoverable.lastPathComponent.hasPrefix(FileSystemService.replaceTempPrefix)
        XCTAssertFalse(strandedUnderTheSweep, "CH-190: the displaced file must not be reachable by `sweepStaleRenameTemps`")
        XCTAssertTrue(FileManager.default.fileExists(atPath: recoverable.path), "the recoverable location must actually exist")
        try? FileManager.default.removeItem(at: recoverable)
    }
}
