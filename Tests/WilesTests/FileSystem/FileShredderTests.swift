import Foundation
@testable import Wiles

@MainActor
public struct FileShredderTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        runDeletePermanentlyCoverage(tempDir: tempDir)
        await runCancellationCoverage(tempDir: tempDir)
        runCancelledPartialNoticeCoverage()

        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func runDeletePermanentlyCoverage(tempDir: URL) {
        // Positive: deletePermanently deletes a real file immediately (bypassing Trash).
        let deleteMeFile = tempDir.appendingPathComponent("delete_me.txt")
        try? "Delete me now".write(to: deleteMeFile, atomically: true, encoding: .utf8)
        var deletePermPassed = false
        do {
            try FileShredderService.deletePermanently(urls: [deleteMeFile])
            deletePermPassed = !FileManager.default.fileExists(atPath: deleteMeFile.path)
        } catch {
            deletePermPassed = false
        }
        TestReporter.report("FileShredder", "POS: deletePermanently immediately deletes a real file", result: deletePermPassed)

        // Negative: deletePermanently on a non-existent path is a no-op, does not throw.
        var deletePermMissingPassed = false
        do {
            let fakePath = tempDir.appendingPathComponent("also_non_existent.txt")
            try FileShredderService.deletePermanently(urls: [fakePath])
            deletePermMissingPassed = true
        } catch {
            deletePermMissingPassed = false
        }
        TestReporter.report("FileShredder", "NEG: deletePermanently on non-existent path handles gracefully without crash", result: deletePermMissingPassed)
    }

    /// Regression coverage for the `Task.checkCancellation()` guard: cancelling the task immediately
    /// after starting it (before the closure has run any loop iteration) proves cancellation is
    /// honored — a missing check would run to completion on every file and the count would be 0.
    private static func runCancellationCoverage(tempDir: URL) async {
        var deleteURLs: [URL] = []
        for index in 0 ..< 25 {
            let url = tempDir.appendingPathComponent("cancel_delete_\(index).txt")
            try? "delete me".write(to: url, atomically: true, encoding: .utf8)
            deleteURLs.append(url)
        }
        let deleteTask = Task {
            try FileShredderService.deletePermanently(urls: deleteURLs)
        }
        deleteTask.cancel()
        _ = try? await deleteTask.value
        let remainingAfterDeleteCancel = deleteURLs.filter { FileManager.default.fileExists(atPath: $0.path) }.count
        TestReporter.report(
            "FileShredder",
            "POS: deletePermanently() honors Task.checkCancellation() and stops before processing any file when cancelled immediately",
            result: remainingAfterDeleteCancel == deleteURLs.count)
        for url in deleteURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// A shred cancelled *after* some files were already deleted must not vanish silently: the
    /// files are permanently gone (no Trash), so `deletePermanently` throws a real, user-visible
    /// error naming "N of M deleted" instead of a `CancellationError` that `runDetachedFileOperation`
    /// swallows. Nothing-deleted-yet still propagates the plain `CancellationError`.
    private static func runCancelledPartialNoticeCoverage() {
        TestReporter.report(
            "FileShredder",
            "NEG: cancelling a shred before anything is deleted surfaces no error notice",
            result: FileShredderService.cancelledPartialError(deletedCount: 0, totalCount: 5) == nil)

        let partial = FileShredderService.cancelledPartialError(deletedCount: 3, totalCount: 10)
        let message = partial.map { ($0 as? WilesError)?.localizedDescription ?? "\($0)" } ?? ""
        TestReporter.report(
            "FileShredder",
            "POS: cancelling a shred after 3 of 10 deletions surfaces an error that names the partial count",
            result: partial != nil && !(partial is CancellationError) && message.contains("3") && message.contains("10"))
    }
}
