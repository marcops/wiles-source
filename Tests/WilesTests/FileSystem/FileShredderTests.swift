@testable import Wiles
import Foundation

@MainActor
public struct FileShredderTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        await runShredCoverage(tempDir: tempDir)
        await runDeletePermanentlyCoverage(tempDir: tempDir)

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
}
