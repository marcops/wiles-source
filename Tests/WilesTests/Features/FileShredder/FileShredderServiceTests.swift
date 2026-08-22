import Foundation
@testable import Wiles

@MainActor
public struct FileShredderFeatureTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileToShred = tempDir.appendingPathComponent("shred.txt")
        try? "Sensitive Data".write(to: fileToShred, atomically: true, encoding: .utf8)

        try? await FileShredderService.shredFiles(urls: [fileToShred])
        report("Feature/FileShredder", "POS: FileShredderService removes file from disk", result: !FileManager.default.fileExists(atPath: fileToShred.path))

        try? await FileShredderService.shredFiles(urls: [fileToShred])
        report("Feature/FileShredder", "NEG: Shredding missing file does not crash", result: true)

        await testResourceValuesFailureAbortsShredInsteadOfSilentlyDeleting()
        await testUnwritableFileAbortsShredInsteadOfSilentlyDeleting()
    }

    /// Covers the `guard let handle = FileHandle(forWritingAtPath:) else { throw }` branch: a
    /// read-only regular file (chmod 0o444) can be opened for reading but not for writing, so
    /// `FileHandle(forWritingAtPath:)` returns nil without needing to fake the filesystem.
    ///
    /// Not covered: the `handle.synchronize()`/`handle.close()` `catch` branches a few lines below
    /// (ErrorReporter.report calls). Forcing those requires yanking the underlying file descriptor out
    /// from under a live `FileHandle` via raw POSIX `close()`, which is fragile/platform-risk-prone and
    /// has no injectable seam in `shredFiles` — disproportionate cost for two log-only catch bodies.
    private static func testUnwritableFileAbortsShredInsteadOfSilentlyDeleting() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tempDir.appendingPathComponent("readonly.txt").path)
            try? FileManager.default.removeItem(at: tempDir)
        }

        let readOnlyFile = tempDir.appendingPathComponent("readonly.txt")
        try? "Sensitive Data".write(to: readOnlyFile, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: readOnlyFile.path)

        var didThrow = false
        do {
            try await FileShredderService.shredFiles(urls: [readOnlyFile])
        } catch {
            didThrow = true
        }

        report(
            "Feature/FileShredder",
            "NEG: shredFiles throws operationFailed instead of deleting when the file can't be opened for writing",
            result: didThrow)
        report(
            "Feature/FileShredder",
            "NEG: read-only file is left on disk when it can't be opened for zero-overwrite",
            result: FileManager.default.fileExists(atPath: readOnlyFile.path))
    }

    /// Bug: `shredFiles` used to read file attributes with `try?`, so any failure reading them
    /// (e.g. a permission error) was silently swallowed and the code fell straight through to a
    /// plain `removeItem` — the file was deleted with no bytes zeroed, yet the caller still saw a
    /// clean success as if the secure zero-overwrite pass had actually run. This proves that when
    /// attribute reading fails, `shredFiles` now aborts and rethrows instead of silently deleting.
    private static func testResourceValuesFailureAbortsShredInsteadOfSilentlyDeleting() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let secretFile = tempDir.appendingPathComponent("secret.txt")
        try? "Sensitive Data".write(to: secretFile, atomically: true, encoding: .utf8)

        struct SimulatedResourceValuesFailure: Error { }

        var didThrow = false
        do {
            try await FileShredderService.shredFiles(urls: [secretFile], resourceValuesProvider: { _ in
                throw SimulatedResourceValuesFailure()
            })
        } catch {
            didThrow = true
        }

        report(
            "Feature/FileShredder",
            "NEG: shredFiles rethrows instead of silently deleting when reading file attributes fails",
            result: didThrow)
        report(
            "Feature/FileShredder",
            "NEG: file is left on disk (not silently removed) when attribute read fails",
            result: FileManager.default.fileExists(atPath: secretFile.path))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
