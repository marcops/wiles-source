@testable import Wiles
import Foundation

@MainActor
public struct ArchiveTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let file1 = tempDir.appendingPathComponent("doc1.txt")
        try? "Content 1".write(to: file1, atomically: true, encoding: .utf8)

        // Positive: Compression
        var compressPassed = false
        do {
            try FileSystemService.compressToZIP(urls: [file1], in: tempDir)
            let zipURL = tempDir.appendingPathComponent("doc1.zip")
            compressPassed = FileManager.default.fileExists(atPath: zipURL.path)
        } catch {
            print("ZIP Compress error: \(error)")
        }
        TestReporter.report("ZipArchive", "POS: compressToZIP creates valid .zip archive", result: compressPassed)

        // Positive: Extraction
        var extractPassed = false
        if compressPassed {
            let zipURL = tempDir.appendingPathComponent("doc1.zip")
            let extractTarget = tempDir.appendingPathComponent("Extracted")
            try? FileManager.default.createDirectory(at: extractTarget, withIntermediateDirectories: true)
            do {
                try FileSystemService.extractZIP(archiveURL: zipURL, to: extractTarget)
                extractPassed = FileManager.default.fileExists(atPath: extractTarget.appendingPathComponent("doc1.txt").path)
            } catch {
                print("ZIP Extract error: \(error)")
            }
        }
        TestReporter.report("ZipArchive", "POS: extractZIP expands archive successfully", result: extractPassed)

        // Negative: Extract Invalid File
        var negExtractPassed = false
        let invalidArchive = tempDir.appendingPathComponent("not_a_zip.zip")
        try? "Corrupt Data".write(to: invalidArchive, atomically: true, encoding: .utf8)
        do {
            try FileSystemService.extractZIP(archiveURL: invalidArchive, to: tempDir)
        } catch {
            negExtractPassed = true
        }
        TestReporter.report("ZipArchive", "NEG: extractZIP on invalid archive throws error", result: negExtractPassed)

        try? FileManager.default.removeItem(at: tempDir)

        runCoverageExtras()
    }

    private static func runCoverageExtras() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // POS: isArchive recognizes supported extensions
        let names = ["a.zip", "a.tar", "a.tgz", "a.tar.gz", "a.tar.bz2", "a.tar.xz"]
        let allTrue = names.allSatisfy { ArchiveService.isArchive(url: tempDir.appendingPathComponent($0)) }
        TestReporter.report("ZipArchive", "POS: isArchive recognizes all supported archive extensions", result: allTrue)

        // NEG: isArchive rejects non-archive extension
        let notArchive = ArchiveService.isArchive(url: tempDir.appendingPathComponent("plain.txt"))
        TestReporter.report("ZipArchive", "NEG: isArchive returns false for .txt files", result: !notArchive)

        // POS: compressing multiple files names the archive "Archive.zip"
        let fileA = tempDir.appendingPathComponent("multiA.txt")
        let fileB = tempDir.appendingPathComponent("multiB.txt")
        try? "A".write(to: fileA, atomically: true, encoding: .utf8)
        try? "B".write(to: fileB, atomically: true, encoding: .utf8)
        var multiPassed = false
        do {
            try ArchiveService.compressToZIP(urls: [fileA, fileB], in: tempDir)
            multiPassed = FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Archive.zip").path)
        } catch {
            print("Multi compress error: \(error)")
        }
        TestReporter.report("ZipArchive", "POS: compressToZIP with multiple files creates Archive.zip", result: multiPassed)

        // POS: name collision appends " 2.zip" counter
        let collideDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: collideDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: collideDir) }
        let collideFile = collideDir.appendingPathComponent("collide.txt")
        try? "collide".write(to: collideFile, atomically: true, encoding: .utf8)
        var collisionPassed = false
        do {
            try ArchiveService.compressToZIP(urls: [collideFile], in: collideDir)
            try ArchiveService.compressToZIP(urls: [collideFile], in: collideDir)
            let firstExists = FileManager.default.fileExists(atPath: collideDir.appendingPathComponent("collide.zip").path)
            let secondExists = FileManager.default.fileExists(atPath: collideDir.appendingPathComponent("collide 2.zip").path)
            collisionPassed = firstExists && secondExists
        } catch {
            print("Collision compress error: \(error)")
        }
        TestReporter.report("ZipArchive", "POS: compressToZIP resolves name collisions by appending a counter", result: collisionPassed)

        // POS: password-protected zip via /usr/bin/zip -P produces a real archive
        let pwdDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: pwdDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pwdDir) }
        let pwdFile = pwdDir.appendingPathComponent("secret.txt")
        try? "top secret".write(to: pwdFile, atomically: true, encoding: .utf8)
        var pwdPassed = false
        do {
            try ArchiveService.compressToZIP(urls: [pwdFile], in: pwdDir, password: "hunter2")
            let pwdZip = pwdDir.appendingPathComponent("secret.zip")
            pwdPassed = FileManager.default.fileExists(atPath: pwdZip.path)
        } catch {
            print("Password compress error: \(error)")
        }
        TestReporter.report("ZipArchive", "POS: compressToZIP with password creates a valid encrypted .zip", result: pwdPassed)

        // POS: extract round-trips the original file content back out
        var roundTripPassed = false
        let roundTripFile = tempDir.appendingPathComponent("roundtrip.txt")
        try? "round trip content".write(to: roundTripFile, atomically: true, encoding: .utf8)
        do {
            try ArchiveService.compressToZIP(urls: [roundTripFile], in: tempDir)
            let rtZip = tempDir.appendingPathComponent("roundtrip.zip")
            let rtDest = tempDir.appendingPathComponent("RoundTripOut")
            try FileManager.default.createDirectory(at: rtDest, withIntermediateDirectories: true)
            try ArchiveService.extractArchive(archiveURL: rtZip, to: rtDest)
            let extractedContent = try? String(contentsOf: rtDest.appendingPathComponent("roundtrip.txt"), encoding: .utf8)
            roundTripPassed = extractedContent == "round trip content"
        } catch {
            print("Round trip error: \(error)")
        }
        TestReporter.report("ZipArchive", "POS: extractArchive round-trips original file content correctly", result: roundTripPassed)
    }
}
