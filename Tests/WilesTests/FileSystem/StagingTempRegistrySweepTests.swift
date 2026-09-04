import Foundation
import XCTest
@testable import Wiles

/// HH-171: `sweepStaleRenameTemps` deletes `.wiles-replace-*` / `.wiles-rename-*` temps older than
/// `staleRenameTempMaxAge`, run at the start of every Replace-move and every case-only rename. Its
/// age heuristic is wrong when a staged file's constructive step (a cross-volume move) runs longer
/// than the threshold: a concurrent operation's sweep then permanently deletes the still-in-use
/// displaced file. `StagingTempRegistry` records in-flight staging UUIDs so the sweep skips them
/// regardless of age; only genuinely unowned (crash-stranded) temps are removed.
final class StagingTempRegistrySweepTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    @discardableResult
    private func makeFile(_ name: String, in dir: URL, ageSeconds: TimeInterval? = nil) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data([1, 2, 3]).write(to: url)
        if let ageSeconds {
            try FileManager.default.setAttributes(
                [.modificationDate: Date().addingTimeInterval(-ageSeconds)], ofItemAtPath: url.path)
        }
        return url
    }

    // MARK: - StagingTempRegistry

    func testRegisterUnregisterRoundTrip() {
        let uuid = UUID().uuidString
        XCTAssertFalse(StagingTempRegistry.isLive(uuid))
        StagingTempRegistry.register(uuid)
        addTeardownBlock { StagingTempRegistry.unregister(uuid) }
        XCTAssertTrue(StagingTempRegistry.isLive(uuid))
        StagingTempRegistry.unregister(uuid)
        XCTAssertFalse(StagingTempRegistry.isLive(uuid))
    }

    func testIsLiveTempFileNameMatchesRegisteredUUIDForEitherPrefix() {
        let uuid = UUID().uuidString
        StagingTempRegistry.register(uuid)
        addTeardownBlock { StagingTempRegistry.unregister(uuid) }
        let prefixes = [FileSystemService.renameTempPrefix, FileSystemService.replaceTempPrefix]

        XCTAssertTrue(StagingTempRegistry.isLiveTempFileName("\(FileSystemService.replaceTempPrefix)\(uuid)", prefixes: prefixes))
        XCTAssertTrue(StagingTempRegistry.isLiveTempFileName("\(FileSystemService.renameTempPrefix)\(uuid)", prefixes: prefixes))
        XCTAssertFalse(
            StagingTempRegistry.isLiveTempFileName("\(FileSystemService.replaceTempPrefix)\(UUID().uuidString)", prefixes: prefixes),
            "an unregistered uuid is treated as an orphan")
        XCTAssertFalse(
            StagingTempRegistry.isLiveTempFileName("Report.txt", prefixes: prefixes),
            "a name with no staging prefix never matches")
    }

    // MARK: - Sweep honours the registry (HH-171 regression)

    func testSweepKeepsAnOldButStillRegisteredReplaceTemp() throws {
        let dir = try makeTempDir()
        let uuid = UUID().uuidString
        // Old enough that the age heuristic alone would delete it — this is exactly the
        // long-running cross-volume Replace case.
        let staged = try makeFile("\(FileSystemService.replaceTempPrefix)\(uuid)", in: dir, ageSeconds: 600)

        StagingTempRegistry.register(uuid)
        addTeardownBlock { StagingTempRegistry.unregister(uuid) }

        FileSystemService.sweepStaleRenameTemps(in: dir, olderThan: 60)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: staged.path),
            "a registered (in-flight) staging temp must survive a concurrent operation's sweep")
    }

    func testSweepRemovesTheSameTempOnceUnregistered() throws {
        let dir = try makeTempDir()
        let uuid = UUID().uuidString
        let staged = try makeFile("\(FileSystemService.replaceTempPrefix)\(uuid)", in: dir, ageSeconds: 600)

        StagingTempRegistry.register(uuid)
        FileSystemService.sweepStaleRenameTemps(in: dir, olderThan: 60)
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.path))

        StagingTempRegistry.unregister(uuid)
        FileSystemService.sweepStaleRenameTemps(in: dir, olderThan: 60)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: staged.path),
            "once the owning operation finishes, an orphan temp is still cleaned up")
    }

    func testSweepStillRemovesAnUnregisteredOrphanAndKeepsUnrelatedFiles() throws {
        let dir = try makeTempDir()
        let orphan = try makeFile("\(FileSystemService.renameTempPrefix)\(UUID().uuidString)", in: dir, ageSeconds: 600)
        let realFile = try makeFile("Report.txt", in: dir, ageSeconds: 600)

        FileSystemService.sweepStaleRenameTemps(in: dir, olderThan: 60)

        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path), "an unowned minutes-old temp is a crash leftover")
        XCTAssertTrue(FileManager.default.fileExists(atPath: realFile.path), "a normal file is never touched")
    }
}
