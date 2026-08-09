@testable import Wiles
import Foundation

@MainActor
public struct ArchiveInspectorFeatureTests {
    public static func run() async {
        let nonExistentArchive = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("nonexistent_\(UUID().uuidString).zip")
        let entries = await ArchiveInspectionService.listEntries(in: nonExistentArchive)
        report("Feature/ArchiveInspector", "NEG: Nonexistent zip returns empty entries", result: entries.isEmpty)
        await runExtractionFailurePreservesExistingDestination()
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
            result: didThrow && contentIntact
        )
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
