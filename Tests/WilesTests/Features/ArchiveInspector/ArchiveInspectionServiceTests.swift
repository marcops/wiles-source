import Foundation
@testable import Wiles

@MainActor
public struct ArchiveInspectorFeatureTests {
    public static func run() async {
        let nonExistentArchive = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("nonexistent_\(UUID().uuidString).zip")
        // M20: an unreadable archive throws now, so the sheet can show an error instead of "no entries".
        var listThrew = false
        do {
            _ = try await ArchiveInspectionService.listEntries(in: nonExistentArchive)
        } catch {
            listThrew = true
        }
        report("Feature/ArchiveInspector", "NEG: listEntries on an unreadable archive throws instead of returning empty", result: listThrew)
        await runExtractionFailurePreservesExistingDestination()
        await runReplaceItemFailureCleansUpTempFileAndRethrows()
    }

    /// Covers `extractSingleEntrySync`'s `replaceItemAt` `catch` block specifically: the destination
    /// directory stays writable (so the temp file is created and extraction succeeds), but the
    /// pre-existing file at `destURL` is marked immutable (`chflags uchg`), so only the final atomic
    /// swap fails. (An empty directory occupying `destURL` was tried first, but `FileManager.
    /// replaceItemAt` is a "safe save" API that can itself swap a plain file into an empty directory's
    /// spot — that did not reliably force a throw.) Proves the temp file is cleaned up and the
    /// original error propagates, rather than a silently-orphaned temp file or a swallowed failure.
    private static func runReplaceItemFailureCleansUpTempFileAndRethrows() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("archive_replace_fail_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceFile = tempDir.appendingPathComponent("payload.txt")
        try? "payload content".write(to: sourceFile, atomically: true, encoding: .utf8)
        try? ArchiveService.compressToZIP(urls: [sourceFile], in: tempDir)
        let zipURL = tempDir.appendingPathComponent("payload.zip")

        let destDir = tempDir.appendingPathComponent("dest")
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destURL = destDir.appendingPathComponent("payload.txt")
        try? "pre-existing".write(to: destURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.immutable: true], ofItemAtPath: destURL.path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: destURL.path) }

        var didThrow = false
        do {
            _ = try await ArchiveInspectionService.extractSingleEntry(from: zipURL, entryPath: "payload.txt", to: destDir)
        } catch {
            didThrow = true
        }

        let leftoverTempFiles = (try? FileManager.default.contentsOfDirectory(atPath: destDir.path))?
            .filter { $0.hasSuffix("_payload.txt") && $0.hasPrefix(".") } ?? []
        report(
            "Feature/ArchiveInspector",
            "NEG: extractSingleEntry rethrows when replaceItemAt fails (destination file is immutable) and removes its own temp file",
            result: didThrow && leftoverTempFiles.isEmpty)
    }

    /// Regression test (see AGENTS.md rule 35): `extractSingleEntry` used to
    /// `FileManager.createFile(atPath: destURL.path, contents: nil, ...)` immediately, which
    /// truncates any pre-existing file at that destination path *before* extraction is known to
    /// succeed. If the `unzip -p` subprocess then failed, the failure path only removed `destURL`
    /// — it never restored the original content, which was already destroyed the moment
    /// `createFile` ran. This must be a safe no-op on failure: the pre-existing destination file's
    /// content must be completely untouched.
    private static func runExtractionFailurePreservesExistingDestination() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("archive_extract_regression_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let entryName = "important.txt"
        let destURL = tempDir.appendingPathComponent(entryName)
        let originalContent = "precious pre-existing user data \(UUID().uuidString)"
        try? originalContent.write(to: destURL, atomically: true, encoding: .utf8)

        // Nonexistent archive guarantees `unzip -p` exits non-zero, forcing the failure path.
        let nonExistentArchive = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("nonexistent_\(UUID().uuidString).zip")

        var didThrow = false
        do {
            _ = try await ArchiveInspectionService.extractSingleEntry(from: nonExistentArchive, entryPath: entryName, to: tempDir)
        } catch {
            didThrow = true
        }

        let contentIntact = (try? String(contentsOf: destURL, encoding: .utf8)) == originalContent
        report(
            "Feature/ArchiveInspector",
            "NEG: extractSingleEntry failure never destroys a pre-existing destination file (regression: used to truncate it via createFile before extraction succeeded)",
            result: didThrow && contentIntact)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
