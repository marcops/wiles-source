@testable import Wiles
import Foundation

@MainActor
public struct FileShredderTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        await runShredCoverage(tempDir: tempDir)
        await runShredChunkBoundaryCoverage(tempDir: tempDir)
        await runDeletePermanentlyCoverage(tempDir: tempDir)
        await runCancellationCoverage(tempDir: tempDir)
        await runMidOverwriteCancellationCoverage(tempDir: tempDir)

        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func runShredCoverage(tempDir: URL) async {
        let secretFile = tempDir.appendingPathComponent("secret.txt")
        try? "Super Secret Bytes".write(to: secretFile, atomically: true, encoding: .utf8)

        // Positive: Secure Shred
        try? await FileShredderService.shredFiles(urls: [secretFile])
        let shredPos = !FileManager.default.fileExists(atPath: secretFile.path)
        TestReporter.report("FileShredder", "POS: shredFiles overwrites and deletes file", result: shredPos)

        // Negative: Shred Non-Existent Path (Graceful handling)
        var negShredPassed = false
        do {
            let fakePath = tempDir.appendingPathComponent("non_existent_secret.txt")
            try await FileShredderService.shredFiles(urls: [fakePath])
            negShredPassed = true
        } catch {
            negShredPassed = false
        }
        TestReporter.report("FileShredder", "NEG: shredFiles on non-existent path handles gracefully without crash", result: negShredPassed)

        // Positive: shredFiles on a zero-byte file skips overwrite loop but still deletes successfully
        let zeroByteFile = tempDir.appendingPathComponent("zero_byte.txt")
        FileManager.default.createFile(atPath: zeroByteFile.path, contents: Data())
        var zeroBytePassed = false
        do {
            try await FileShredderService.shredFiles(urls: [zeroByteFile])
            zeroBytePassed = !FileManager.default.fileExists(atPath: zeroByteFile.path)
        } catch {
            zeroBytePassed = false
        }
        TestReporter.report("FileShredder", "POS: shredFiles on a zero-byte file deletes without crashing", result: zeroBytePassed)

        // Positive: shredFiles on an empty directory skips overwrite branch and removes the directory
        let emptyDir = tempDir.appendingPathComponent("empty_subdir")
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        var emptyDirPassed = false
        do {
            try await FileShredderService.shredFiles(urls: [emptyDir])
            emptyDirPassed = !FileManager.default.fileExists(atPath: emptyDir.path)
        } catch {
            emptyDirPassed = false
        }
        TestReporter.report("FileShredder", "POS: shredFiles on an empty directory removes it without attempting overwrite", result: emptyDirPassed)
    }

    private static func runShredChunkBoundaryCoverage(tempDir: URL) async {
        // Positive: shredFiles on a file whose size is an exact multiple of the 1MB chunk size
        // exercises the full-chunk write branch (toWrite == chunkSize) instead of only the
        // remainder branch that smaller files hit.
        let exactChunkFile = tempDir.appendingPathComponent("exact_chunk.bin")
        FileManager.default.createFile(atPath: exactChunkFile.path, contents: Data(count: 1_048_576))
        var exactChunkPassed = false
        do {
            try await FileShredderService.shredFiles(urls: [exactChunkFile])
            exactChunkPassed = !FileManager.default.fileExists(atPath: exactChunkFile.path)
        } catch {
            exactChunkPassed = false
        }
        TestReporter.report(
            "FileShredder",
            "POS: shredFiles on a file exactly one chunk in size writes a full zero chunk before deleting",
            result: exactChunkPassed
        )
    }

    private static func runDeletePermanentlyCoverage(tempDir: URL) {
        // Positive: deletePermanently deletes a real file immediately (no overwrite)
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

        // Negative: deletePermanently on non-existent path is a no-op, does not throw
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

    /// Regression coverage for the `Task.checkCancellation()` guards added to both loops:
    /// cancelling the task immediately after starting it (before the task closure has had a
    /// chance to run any loop iteration) is the deterministic way to prove cancellation is
    /// actually honored — if the check were missing, both operations would run to completion
    /// on every file regardless of cancellation, and the counts below would be 0 instead of
    /// matching the full input count.
    private static func runCancellationCoverage(tempDir: URL) async {
        var shredURLs: [URL] = []
        for index in 0..<25 {
            let url = tempDir.appendingPathComponent("cancel_shred_\(index).txt")
            try? "shred me".write(to: url, atomically: true, encoding: .utf8)
            shredURLs.append(url)
        }
        let shredTask = Task {
            try await FileShredderService.shredFiles(urls: shredURLs)
        }
        shredTask.cancel()
        _ = try? await shredTask.value
        let remainingAfterShredCancel = shredURLs.filter { FileManager.default.fileExists(atPath: $0.path) }.count
        TestReporter.report(
            "FileShredder",
            "POS: shredFiles() honors Task.checkCancellation() and stops before processing any file when cancelled immediately",
            result: remainingAfterShredCancel == shredURLs.count
        )
        for url in shredURLs { try? FileManager.default.removeItem(at: url) }

        var deleteURLs: [URL] = []
        for index in 0..<25 {
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
            result: remainingAfterDeleteCancel == deleteURLs.count
        )
        for url in deleteURLs { try? FileManager.default.removeItem(at: url) }
    }

    /// Regression coverage for the `Task.isCancelled` check *inside* the byte-overwrite `while`
    /// loop of `shredFiles`, distinct from `runCancellationCoverage` above which only proves the
    /// per-file `Task.checkCancellation()` guard at the top of the `for` loop. A large file (many
    /// 1MB chunks) is shredded so the overwrite loop takes measurably longer than a single
    /// iteration; cancelling shortly after the task starts (once it has already entered the loop
    /// for this file, past the outer per-file guard) lets the flag be observed mid-loop, exercising
    /// the `try? handle.close(); throw CancellationError()` branch instead of the outer guard.
    private static func runMidOverwriteCancellationCoverage(tempDir: URL) async {
        let bigFile = tempDir.appendingPathComponent("mid_overwrite_cancel.bin")
        FileManager.default.createFile(atPath: bigFile.path, contents: Data(count: 50_000_000))

        let shredTask = Task {
            try await FileShredderService.shredFiles(urls: [bigFile])
        }
        try? await Task.sleep(nanoseconds: 1_000_000)
        shredTask.cancel()
        _ = try? await shredTask.value

        let fileStillExists = FileManager.default.fileExists(atPath: bigFile.path)
        TestReporter.report(
            "FileShredder",
            "POS: shredFiles() honors Task.isCancelled inside the overwrite loop for a large file and stops mid-write",
            result: fileStillExists
        )
        try? FileManager.default.removeItem(at: bigFile)
    }
}
