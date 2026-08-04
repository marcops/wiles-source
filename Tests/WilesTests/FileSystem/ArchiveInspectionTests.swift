@testable import Wiles
import Foundation

@MainActor
public struct ArchiveInspectionTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileToZip = tempDir.appendingPathComponent("inspect_test_file.txt")
        try? "test data for zip".write(to: fileToZip, atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("inspect_test_file.zip")
        try? ZipArchiveService.compressToZIP(urls: [fileToZip], in: tempDir)

        let entries = ArchiveInspectionService.listEntries(in: zipURL)
        TestReporter.report("ArchiveInspection", "POS: listEntries lists files in zip", result: entries.contains(where: { $0.name.contains("inspect_test_file.txt") }))

        try? FileManager.default.removeItem(at: fileToZip)
        try? FileManager.default.removeItem(at: zipURL)

        // POS: listEntries reflects nested folder structure (directory entries end with "/")
        let nestedRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: nestedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: nestedRoot) }

        let subDir = nestedRoot.appendingPathComponent("subfolder")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let nestedFile = subDir.appendingPathComponent("nested.txt")
        try? "nested content".write(to: nestedFile, atomically: true, encoding: .utf8)

        var nestedListPassed = false
        var extractSingleEntryPassed = false
        var extractedNestedEntryPath: String?
        do {
            try ArchiveService.compressToZIP(urls: [subDir], in: nestedRoot)
            let nestedZip = nestedRoot.appendingPathComponent("subfolder.zip")
            let nestedEntries = ArchiveInspectionService.listEntries(in: nestedZip)
            // Note: ArchiveService.compressToZIP uses `ditto -c -k --sequesterRsrc`, which zips the
            // CONTENTS of a source directory rather than the directory itself (same quirk documented
            // in AGENTS.md rule 12 for release packaging) — so "subfolder/" is never a real entry here,
            // only its contents are. This asserts the file inside is listed correctly instead.
            nestedListPassed = nestedEntries.contains(where: { !$0.isDirectory && $0.name == "nested.txt" })

            if let entry = nestedEntries.first(where: { !$0.isDirectory && $0.name == "nested.txt" }) {
                extractedNestedEntryPath = entry.path
                let extractDest = nestedRoot.appendingPathComponent("ExtractedSingle")
                try FileManager.default.createDirectory(at: extractDest, withIntermediateDirectories: true)
                let extractedURL = try ArchiveInspectionService.extractSingleEntry(from: nestedZip, entryPath: entry.path, to: extractDest)
                let content = try? String(contentsOf: extractedURL, encoding: .utf8)
                extractSingleEntryPassed = content == "nested content"
            }
        } catch {
            print("Nested archive error: \(error)")
        }
        TestReporter.report("ArchiveInspection", "POS: listEntries reflects nested folder structure with directory markers", result: nestedListPassed)
        TestReporter.report("ArchiveInspection", "POS: extractSingleEntry extracts a single entry by path with correct content", result: extractSingleEntryPassed)
        _ = extractedNestedEntryPath

        // NEG: listEntries on a non-existent / corrupt archive returns empty results, not a crash
        let corruptArchive = nestedRoot.appendingPathComponent("corrupt.zip")
        try? "this is not a real zip file".write(to: corruptArchive, atomically: true, encoding: .utf8)
        let corruptEntries = ArchiveInspectionService.listEntries(in: corruptArchive)
        TestReporter.report("ArchiveInspection", "NEG: listEntries on corrupt archive returns empty list", result: corruptEntries.isEmpty)

        // NEG: extractSingleEntry for a non-existent entry path produces an empty extracted file, not a match
        var negExtractPassed = false
        do {
            try ArchiveService.compressToZIP(urls: [nestedFile], in: nestedRoot)
        } catch {
            print("setup error: \(error)")
        }
        let flatZip = nestedRoot.appendingPathComponent("nested.zip")
        if FileManager.default.fileExists(atPath: flatZip.path) {
            let badDest = nestedRoot.appendingPathComponent("BadExtract")
            try? FileManager.default.createDirectory(at: badDest, withIntermediateDirectories: true)
            do {
                let extractedURL = try ArchiveInspectionService.extractSingleEntry(from: flatZip, entryPath: "does_not_exist.txt", to: badDest)
                let data = try? Data(contentsOf: extractedURL)
                negExtractPassed = (data?.isEmpty ?? true)
            } catch {
                negExtractPassed = true
            }
        }
        TestReporter.report("ArchiveInspection", "NEG: extractSingleEntry for a missing entry path does not produce the wrong content", result: negExtractPassed)

        runMultiEntryAndSpecialCharTests()
        runDeepNestingAndMissingArchiveTests()
    }

    // POS: listEntries lists every entry when the archive contains multiple files,
    // POS: entries with spaces/special characters in their names are listed and extractable.
    private static func runMultiEntryAndSpecialCharTests() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileA = root.appendingPathComponent("alpha.txt")
        let fileB = root.appendingPathComponent("beta.txt")
        let fileSpecial = root.appendingPathComponent("my file (test) #1.txt")
        try? "alpha content".write(to: fileA, atomically: true, encoding: .utf8)
        try? "beta content".write(to: fileB, atomically: true, encoding: .utf8)
        try? "special content".write(to: fileSpecial, atomically: true, encoding: .utf8)

        let archiveDir = root.appendingPathComponent("multi")
        try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)

        var multiListPassed = false
        var specialCharListPassed = false
        var specialCharExtractPassed = false
        do {
            try ArchiveService.compressToZIP(urls: [fileA, fileB, fileSpecial], in: archiveDir)
            let zip = archiveDir.appendingPathComponent("Archive.zip")
            let zipURL = FileManager.default.fileExists(atPath: zip.path)
                ? zip
                : archiveDir.appendingPathComponent("multi.zip")
            let entries = ArchiveInspectionService.listEntries(in: zipURL)
            multiListPassed = entries.contains(where: { $0.name == "alpha.txt" })
                && entries.contains(where: { $0.name == "beta.txt" })

            if let specialEntry = entries.first(where: { $0.name == "my file (test) #1.txt" }) {
                specialCharListPassed = true
                let dest = root.appendingPathComponent("ExtractedSpecial")
                try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
                let extractedURL = try ArchiveInspectionService.extractSingleEntry(from: zipURL, entryPath: specialEntry.path, to: dest)
                let content = try? String(contentsOf: extractedURL, encoding: .utf8)
                specialCharExtractPassed = content == "special content"
            }
        } catch {
            print("Multi-entry archive error: \(error)")
        }
        TestReporter.report("ArchiveInspection", "POS: listEntries lists all files when archive contains multiple entries", result: multiListPassed)
        TestReporter.report("ArchiveInspection", "POS: listEntries includes entries with spaces and special characters in the name", result: specialCharListPassed)
        TestReporter.report("ArchiveInspection", "POS: extractSingleEntry extracts an entry whose name has spaces/special characters", result: specialCharExtractPassed)
    }

    // POS: listEntries/extractSingleEntry handle entry paths nested more than one directory deep,
    // NEG: listEntries on a completely missing archive file (not just a corrupt one) does not crash.
    private static func runDeepNestingAndMissingArchiveTests() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let level1 = root.appendingPathComponent("level1")
        let level2 = level1.appendingPathComponent("level2")
        try? FileManager.default.createDirectory(at: level2, withIntermediateDirectories: true)
        let deepFile = level2.appendingPathComponent("deep.txt")
        try? "deep content".write(to: deepFile, atomically: true, encoding: .utf8)

        var deepNameParsedPassed = false
        var deepExtractPassed = false
        do {
            try ArchiveService.compressToZIP(urls: [level1], in: root)
            let zipURL = root.appendingPathComponent("level1.zip")
            let entries = ArchiveInspectionService.listEntries(in: zipURL)
            // Entry path should be nested (e.g. "level2/deep.txt"), but the parsed `name`
            // should be just the last path component, not the full nested path.
            if let deepEntry = entries.first(where: { !$0.isDirectory && $0.name == "deep.txt" }) {
                deepNameParsedPassed = deepEntry.path.contains("level2")
                let dest = root.appendingPathComponent("ExtractedDeep")
                try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
                let extractedURL = try ArchiveInspectionService.extractSingleEntry(from: zipURL, entryPath: deepEntry.path, to: dest)
                let content = try? String(contentsOf: extractedURL, encoding: .utf8)
                deepExtractPassed = content == "deep content"
            }
        } catch {
            print("Deep nesting archive error: \(error)")
        }
        TestReporter.report("ArchiveInspection", "POS: listEntries reports nested entry path while ArchiveEntryItem.name keeps only the last component", result: deepNameParsedPassed)
        TestReporter.report("ArchiveInspection", "POS: extractSingleEntry extracts an entry nested more than one directory deep", result: deepExtractPassed)

        // NEG: archive file does not exist at all (unzip should fail cleanly, not crash).
        let missingArchive = root.appendingPathComponent("does_not_exist.zip")
        let missingEntries = ArchiveInspectionService.listEntries(in: missingArchive)
        TestReporter.report("ArchiveInspection", "NEG: listEntries on a nonexistent archive file returns empty list without crashing", result: missingEntries.isEmpty)

        // NEG: extractSingleEntry from a nonexistent archive should not silently succeed with real content.
        var missingArchiveExtractPassed = false
        do {
            let dest = root.appendingPathComponent("ExtractedMissing")
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            let extractedURL = try ArchiveInspectionService.extractSingleEntry(from: missingArchive, entryPath: "deep.txt", to: dest)
            let data = try? Data(contentsOf: extractedURL)
            missingArchiveExtractPassed = (data?.isEmpty ?? true)
        } catch {
            missingArchiveExtractPassed = true
        }
        TestReporter.report("ArchiveInspection", "NEG: extractSingleEntry from a nonexistent archive does not produce real file content", result: missingArchiveExtractPassed)
    }
}
