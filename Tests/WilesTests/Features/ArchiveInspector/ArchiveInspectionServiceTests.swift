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
        await runExtractingOntoExistingNameKeepsBoth()
        await runExtractEntryWithGlobCharsInNameExtractsTheRightFile()
        await runExtractEntryWithNonASCIIName()
        await runExtractPlainAsciiEntryStreamsJustThatEntry()
    }

    /// A plain ASCII entry name takes the `unzip -p` stream path (no whole-archive staging) and
    /// still comes out with exactly that entry's bytes.
    private static func runExtractPlainAsciiEntryStreamsJustThatEntry() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("archive_fastpath_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let wanted = dir.appendingPathComponent("wanted.txt")
        let other = dir.appendingPathComponent("other.txt")
        try? "THE ONE I WANT".write(to: wanted, atomically: true, encoding: .utf8)
        try? String(repeating: "x", count: 4096).write(to: other, atomically: true, encoding: .utf8)
        try? ArchiveService.compressToZIP(urls: [wanted, other], in: dir)
        let zipURL = dir.appendingPathComponent("Archive.zip")

        let destDir = dir.appendingPathComponent("dest")
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        var content: String?
        var onlyOneFileLanded = false
        do {
            let url = try await ArchiveInspectionService.extractSingleEntry(from: zipURL, entryPath: "wanted.txt", to: destDir)
            content = try? String(contentsOf: url, encoding: .utf8)
            onlyOneFileLanded = ((try? FileManager.default.contentsOfDirectory(atPath: destDir.path)) ?? []).count == 1
        } catch {
            content = nil
        }
        report(
            "Feature/ArchiveInspector",
            "POS: extractSingleEntry on a plain ASCII name returns just that entry's bytes without extracting the rest",
            result: content == "THE ONE I WANT" && onlyOneFileLanded)
    }

    /// B9-3: extraction goes through `ditto -x`, not `/usr/bin/unzip`, so an entry whose name has
    /// non-ASCII characters comes out with the right bytes instead of failing to match.
    private static func runExtractEntryWithNonASCIIName() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("archive_nonascii_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let entryName = "Отчёт—2024 café 日本語.txt"
        let sourceFile = tempDir.appendingPathComponent(entryName)
        try? "UNICODE ENTRY CONTENT".write(to: sourceFile, atomically: true, encoding: .utf8)
        try? ArchiveService.compressToZIP(urls: [sourceFile], in: tempDir)
        let zipURL = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path))?
            .first { $0.hasSuffix(".zip") }
            .map { tempDir.appendingPathComponent($0) }

        let destDir = tempDir.appendingPathComponent("out")
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        var extractedContent: String?
        var extractedName: String?
        if let zipURL {
            do {
                let url = try await ArchiveInspectionService.extractSingleEntry(from: zipURL, entryPath: entryName, to: destDir)
                extractedContent = try? String(contentsOf: url, encoding: .utf8)
                extractedName = url.lastPathComponent
            } catch {
                extractedContent = nil
            }
        }
        report(
            "Feature/ArchiveInspector",
            "POS: extractSingleEntry on a non-ASCII entry name returns that file with its bytes intact",
            result: extractedContent == "UNICODE ENTRY CONTENT" && extractedName == entryName)
    }

    /// An archive containing both `foo[1].txt` and `foo1.txt`: extracting `foo[1].txt` must yield
    /// that exact file's bytes, not `foo1.txt` — `ditto -x` extracts the literal tree, so a name
    /// with glob metacharacters is no longer a hazard the way `unzip`'s file-spec glob was.
    private static func runExtractEntryWithGlobCharsInNameExtractsTheRightFile() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("archive_glob_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let bracketFile = tempDir.appendingPathComponent("foo[1].txt")
        let plainFile = tempDir.appendingPathComponent("foo1.txt")
        try? "BRACKET CONTENT".write(to: bracketFile, atomically: true, encoding: .utf8)
        try? "PLAIN CONTENT".write(to: plainFile, atomically: true, encoding: .utf8)
        try? ArchiveService.compressToZIP(urls: [bracketFile, plainFile], in: tempDir)
        let zipURL = tempDir.appendingPathComponent("foo[1].zip")
        // ArchiveService names the zip after the first url's stem; fall back to any .zip present.
        let actualZip = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path))?
            .first { $0.hasSuffix(".zip") }
            .map { tempDir.appendingPathComponent($0) } ?? zipURL

        let destDir = tempDir.appendingPathComponent("out")
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        var extractedContent: String?
        do {
            let url = try await ArchiveInspectionService.extractSingleEntry(from: actualZip, entryPath: "foo[1].txt", to: destDir)
            extractedContent = try? String(contentsOf: url, encoding: .utf8)
        } catch {
            extractedContent = nil
        }
        report(
            "Feature/ArchiveInspector",
            "POS: extractSingleEntry on an entry named foo[1].txt returns that file, not the glob-matched foo1.txt",
            result: extractedContent == "BRACKET CONTENT")
    }

    /// Regression for B9-1: extracting an entry into a folder that already contains a file of the
    /// same name must **keep both** — the pre-existing file is untouched and the extracted entry
    /// lands under a free "name 2.ext" name — never overwrite (the old code used `replaceItemAt`,
    /// which sends the existing file to a backup and deletes it, with no prompt / no keep-both).
    private static func runExtractingOntoExistingNameKeepsBoth() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("archive_keepboth_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceFile = tempDir.appendingPathComponent("payload.txt")
        try? "ARCHIVED CONTENT".write(to: sourceFile, atomically: true, encoding: .utf8)
        try? ArchiveService.compressToZIP(urls: [sourceFile], in: tempDir)
        let zipURL = tempDir.appendingPathComponent("payload.zip")

        let destDir = tempDir.appendingPathComponent("dest")
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let existing = destDir.appendingPathComponent("payload.txt")
        try? "PRE-EXISTING USER FILE".write(to: existing, atomically: true, encoding: .utf8)

        var extractedURL: URL?
        do {
            extractedURL = try await ArchiveInspectionService.extractSingleEntry(from: zipURL, entryPath: "payload.txt", to: destDir)
        } catch {
            extractedURL = nil
        }

        let existingIntact = (try? String(contentsOf: existing, encoding: .utf8)) == "PRE-EXISTING USER FILE"
        let extractedIsFreshName = extractedURL?.lastPathComponent == "payload 2.txt"
        let extractedContent = extractedURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        let leftoverTempFiles = (try? FileManager.default.contentsOfDirectory(atPath: destDir.path))?
            .filter { $0.hasSuffix("_payload.txt") && $0.hasPrefix(".") } ?? []
        report(
            "Feature/ArchiveInspector",
            "REG: extractSingleEntry onto an existing name keeps both (existing untouched, entry lands as 'payload 2.txt'), no leftover temp",
            result: existingIntact && extractedIsFreshName && extractedContent == "ARCHIVED CONTENT" && leftoverTempFiles.isEmpty)
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
        let leftoverTempFiles = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path))?
            .filter { $0.hasSuffix("_\(entryName)") && $0.hasPrefix(".") } ?? []
        report(
            "Feature/ArchiveInspector",
            "NEG: extractSingleEntry failure never destroys a pre-existing destination file and leaves no temp file behind",
            result: didThrow && contentIntact && leftoverTempFiles.isEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
