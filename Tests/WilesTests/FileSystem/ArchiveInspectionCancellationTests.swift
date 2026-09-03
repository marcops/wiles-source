import Foundation
import XCTest
@testable import Wiles

/// MM-078: `ArchiveInspectionService`'s single-entry extraction used a bare `process.waitUntilExit()`
/// (closing the sheet couldn't stop the `ditto`/`unzip` work) and left its `.<UUID>_unzip` staging
/// dir with no crash-recovery sweep. Covers the two fixes: `ArchiveService.waitForExitOrCancel`
/// (poll-terminate-throw) and `ArchiveInspectionService.sweepStaleUnzipStagingDirs`.
final class ArchiveInspectionCancellationTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    @discardableResult
    private func makeDir(_ name: String, in parent: URL, ageSeconds: TimeInterval? = nil) throws -> URL {
        let url = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data([0]).write(to: url.appendingPathComponent("payload.bin"))
        if let ageSeconds {
            try FileManager.default.setAttributes(
                [.modificationDate: Date().addingTimeInterval(-ageSeconds)], ofItemAtPath: url.path)
        }
        return url
    }

    // MARK: - sweepStaleUnzipStagingDirs

    func testSweepRemovesOnlyStaleUnzipStagingDirs() throws {
        let dir = try makeTempDir()
        let stale = try makeDir("\(ArchiveInspectionService.unzipStagingPrefix)crashed", in: dir, ageSeconds: 300)
        let fresh = try makeDir("\(ArchiveInspectionService.unzipStagingPrefix)inflight", in: dir)
        let realFolder = try makeDir("Documents", in: dir, ageSeconds: 999)
        let dotFolder = try makeDir(".hidden", in: dir, ageSeconds: 999)

        ArchiveInspectionService.sweepStaleUnzipStagingDirs(in: dir, olderThan: 60)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path), "a minutes-old staging dir is a crash leftover")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path), "a fresh staging dir belongs to a concurrent extraction")
        XCTAssertTrue(FileManager.default.fileExists(atPath: realFolder.path), "only the staging prefix is swept")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dotFolder.path))
    }

    func testSweepOnMissingDirectoryIsANoOp() throws {
        let dir = try makeTempDir()
        ArchiveInspectionService.sweepStaleUnzipStagingDirs(in: dir.appendingPathComponent("nope"))
    }

    // MARK: - ArchiveService.waitForExitOrCancel

    func testWaitForExitReturnsNormallyForAProcessThatExitsOnItsOwn() async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sleep")
            process.arguments = ["0.1"]
            try process.run()
            try ArchiveService.waitForExitOrCancel(process)
            XCTAssertEqual(process.terminationStatus, 0)
            XCTAssertFalse(process.isRunning)
        }.value
    }

    func testWaitForExitTerminatesTheSubprocessAndThrowsWhenTheTaskIsCancelled() async {
        final class Box: @unchecked Sendable {
            private let lock = NSLock()
            private var _process: Process?
            var process: Process? {
                get { lock.withLock { _process } }
                set { lock.withLock { _process = newValue } }
            }
        }
        let box = Box()

        // Same wrapper production uses (`CancellableWork.detached`) — it forwards the outer task's
        // cancellation into the detached body, which a bare `Task.detached` does not.
        let outer = Task { () -> Bool in
            do {
                try await CancellableWork.detached {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/sleep")
                    process.arguments = ["30"]
                    try process.run()
                    box.process = process
                    try ArchiveService.waitForExitOrCancel(process)
                }
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }

        try? await Task.sleep(for: .milliseconds(300))
        outer.cancel()
        let threw = await outer.value

        XCTAssertTrue(threw, "a cancelled wait must throw CancellationError, not run the subprocess to completion")
        try? await Task.sleep(for: .milliseconds(300))
        let leftoverProcess = box.process
        XCTAssertEqual(leftoverProcess?.isRunning, false, "the `sleep 30` subprocess must have been SIGTERM'd, not left running")
        if let leftoverProcess, leftoverProcess.isRunning {
            leftoverProcess.terminate()
        }
    }
}
