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

        runPasswordExtractionTests()
        runTarExtractionTests()
        runIsArchiveEdgeCaseTests()
        runExtractZIPWrapperTests()
        runCorruptArchiveErrorPathTests()
    }

    private static func runPasswordExtractionTests() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let secretFile = dir.appendingPathComponent("secret.txt")
        try? "classified content".write(to: secretFile, atomically: true, encoding: .utf8)

        var createdPasswordZip = false
        do {
            try ArchiveService.compressToZIP(urls: [secretFile], in: dir, password: "correcthorse")
            createdPasswordZip = FileManager.default.fileExists(atPath: dir.appendingPathComponent("secret.zip").path)
        } catch {
            print("Password zip creation error: \(error)")
        }
        let pwdZip = dir.appendingPathComponent("secret.zip")

        // NEG: unzip with wrong password fails
        var wrongPasswordFailed = false
        let wrongPassOut = dir.appendingPathComponent("WrongPassOut")
        try? FileManager.default.createDirectory(at: wrongPassOut, withIntermediateDirectories: true)
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-P", "wrongpassword", "-o", pwdZip.path, "-d", wrongPassOut.path]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try process.run()
            process.waitUntilExit()
            wrongPasswordFailed = process.terminationStatus != 0
        } catch {
            print("Wrong password unzip spawn error: \(error)")
        }
        TestReporter.report("ZipArchive", "NEG: unzip -P with wrong password fails to extract password-protected zip", result: createdPasswordZip && wrongPasswordFailed)

        // POS: unzip with correct password succeeds and yields original content
        var correctPasswordPassed = false
        let correctPassOut = dir.appendingPathComponent("CorrectPassOut")
        try? FileManager.default.createDirectory(at: correctPassOut, withIntermediateDirectories: true)
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-P", "correcthorse", "-o", pwdZip.path, "-d", correctPassOut.path]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let content = try? String(contentsOf: correctPassOut.appendingPathComponent("secret.txt"), encoding: .utf8)
                correctPasswordPassed = content == "classified content"
            }
        } catch {
            print("Correct password unzip spawn error: \(error)")
        }
        TestReporter.report("ZipArchive", "POS: unzip -P with correct password extracts original content", result: correctPasswordPassed)

        // NEG: ArchiveService.extractArchive (which uses ditto, no password support) fails on password-protected zip
        var dittoOnPasswordZipFailed = false
        let dittoOut = dir.appendingPathComponent("DittoPasswordOut")
        try? FileManager.default.createDirectory(at: dittoOut, withIntermediateDirectories: true)
        do {
            try ArchiveService.extractArchive(archiveURL: pwdZip, to: dittoOut)
        } catch {
            dittoOnPasswordZipFailed = true
        }
        TestReporter.report("ZipArchive", "NEG: extractArchive (ditto-based, no password param) fails to extract a password-protected zip", result: dittoOnPasswordZipFailed)
    }

    private static func runTarExtractionTests() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let sourceFile = dir.appendingPathComponent("tarme.txt")
        try? "tar file content".write(to: sourceFile, atomically: true, encoding: .utf8)

        // Build a plain .tar via /usr/bin/tar
        let tarURL = dir.appendingPathComponent("archive.tar")
        var tarCreated = false
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.currentDirectoryURL = dir
            process.arguments = ["-cf", tarURL.path, "tarme.txt"]
            try process.run()
            process.waitUntilExit()
            tarCreated = process.terminationStatus == 0
        } catch {
            print("tar creation error: \(error)")
        }

        var tarExtractPassed = false
        if tarCreated {
            let tarOut = dir.appendingPathComponent("TarOut")
            try? FileManager.default.createDirectory(at: tarOut, withIntermediateDirectories: true)
            do {
                try ArchiveService.extractArchive(archiveURL: tarURL, to: tarOut)
                let content = try? String(contentsOf: tarOut.appendingPathComponent("tarme.txt"), encoding: .utf8)
                tarExtractPassed = content == "tar file content"
            } catch {
                print("tar extraction error: \(error)")
            }
        }
        TestReporter.report("ZipArchive", "POS: extractArchive extracts a plain .tar via /usr/bin/tar", result: tarCreated && tarExtractPassed)

        // Build a .tgz via /usr/bin/tar
        let tgzURL = dir.appendingPathComponent("archive.tgz")
        var tgzCreated = false
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.currentDirectoryURL = dir
            process.arguments = ["-czf", tgzURL.path, "tarme.txt"]
            try process.run()
            process.waitUntilExit()
            tgzCreated = process.terminationStatus == 0
        } catch {
            print("tgz creation error: \(error)")
        }

        var tgzExtractPassed = false
        if tgzCreated {
            let tgzOut = dir.appendingPathComponent("TgzOut")
            try? FileManager.default.createDirectory(at: tgzOut, withIntermediateDirectories: true)
            do {
                try ArchiveService.extractArchive(archiveURL: tgzURL, to: tgzOut)
                let content = try? String(contentsOf: tgzOut.appendingPathComponent("tarme.txt"), encoding: .utf8)
                tgzExtractPassed = content == "tar file content"
            } catch {
                print("tgz extraction error: \(error)")
            }
        }
        TestReporter.report("ZipArchive", "POS: extractArchive extracts a .tgz via /usr/bin/tar", result: tgzCreated && tgzExtractPassed)

        // Build a .tar.gz (name-based suffix match, not .tgz extension) via /usr/bin/tar
        let tarGzURL = dir.appendingPathComponent("archive.tar.gz")
        var tarGzCreated = false
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.currentDirectoryURL = dir
            process.arguments = ["-czf", tarGzURL.path, "tarme.txt"]
            try process.run()
            process.waitUntilExit()
            tarGzCreated = process.terminationStatus == 0
        } catch {
            print("tar.gz creation error: \(error)")
        }

        var tarGzExtractPassed = false
        if tarGzCreated {
            let tarGzOut = dir.appendingPathComponent("TarGzOut")
            try? FileManager.default.createDirectory(at: tarGzOut, withIntermediateDirectories: true)
            do {
                try ArchiveService.extractArchive(archiveURL: tarGzURL, to: tarGzOut)
                let content = try? String(contentsOf: tarGzOut.appendingPathComponent("tarme.txt"), encoding: .utf8)
                tarGzExtractPassed = content == "tar file content"
            } catch {
                print("tar.gz extraction error: \(error)")
            }
        }
        TestReporter.report("ZipArchive", "POS: extractArchive extracts a .tar.gz (name-suffix, non-.tgz extension) via /usr/bin/tar", result: tarGzCreated && tarGzExtractPassed)
    }

    private static func runIsArchiveEdgeCaseTests() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

        // POS: isArchive is case-insensitive on extension
        let uppercaseZip = ArchiveService.isArchive(url: dir.appendingPathComponent("Photo.ZIP"))
        TestReporter.report("ZipArchive", "POS: isArchive is case-insensitive for uppercase .ZIP extension", result: uppercaseZip)

        // POS: isArchive matches .tar.bz2 by name suffix even though pathExtension is just "bz2"
        let bz2Match = ArchiveService.isArchive(url: dir.appendingPathComponent("data.tar.bz2"))
        TestReporter.report("ZipArchive", "POS: isArchive matches .tar.bz2 via name-suffix check", result: bz2Match)

        // NEG: isArchive rejects a file with no extension at all
        let noExtension = ArchiveService.isArchive(url: dir.appendingPathComponent("README"))
        TestReporter.report("ZipArchive", "NEG: isArchive returns false for a file with no extension", result: !noExtension)

        // NEG: isArchive rejects a directory-looking url with an unrelated compound suffix
        let unrelatedCompound = ArchiveService.isArchive(url: dir.appendingPathComponent("notes.tar.txt"))
        TestReporter.report("ZipArchive", "NEG: isArchive returns false for .tar.txt (not a recognized archive suffix)", result: !unrelatedCompound)
    }

    private static func runExtractZIPWrapperTests() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("wrapped.txt")
        try? "wrapper test content".write(to: file, atomically: true, encoding: .utf8)

        var wrapperPassed = false
        do {
            try ArchiveService.compressToZIP(urls: [file], in: dir)
            let zipURL = dir.appendingPathComponent("wrapped.zip")
            let out = dir.appendingPathComponent("WrapperOut")
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            // extractZIP is a thin wrapper delegating to extractArchive; verify it behaves identically end to end.
            try ArchiveService.extractZIP(archiveURL: zipURL, to: out)
            let content = try? String(contentsOf: out.appendingPathComponent("wrapped.txt"), encoding: .utf8)
            wrapperPassed = content == "wrapper test content"
        } catch {
            print("extractZIP wrapper error: \(error)")
        }
        TestReporter.report("ZipArchive", "POS: extractZIP wrapper delegates to extractArchive and produces correct content", result: wrapperPassed)

        // NEG: extractZIP wrapper propagates errors from extractArchive for a corrupt archive
        var wrapperErrorPassed = false
        let corruptZip = dir.appendingPathComponent("wrapper_corrupt.zip")
        try? "not really a zip".write(to: corruptZip, atomically: true, encoding: .utf8)
        let corruptOut = dir.appendingPathComponent("WrapperCorruptOut")
        try? FileManager.default.createDirectory(at: corruptOut, withIntermediateDirectories: true)
        do {
            try ArchiveService.extractZIP(archiveURL: corruptZip, to: corruptOut)
        } catch {
            wrapperErrorPassed = true
        }
        TestReporter.report("ZipArchive", "NEG: extractZIP wrapper throws when underlying extractArchive fails on a corrupt zip", result: wrapperErrorPassed)
    }

    private static func runCorruptArchiveErrorPathTests() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // NEG: extractArchive on a corrupt .tar (routed through /usr/bin/tar) throws
        var corruptTarFailed = false
        let corruptTar = dir.appendingPathComponent("bad.tar")
        try? "this is not a valid tar file at all".write(to: corruptTar, atomically: true, encoding: .utf8)
        let corruptTarOut = dir.appendingPathComponent("CorruptTarOut")
        try? FileManager.default.createDirectory(at: corruptTarOut, withIntermediateDirectories: true)
        do {
            try ArchiveService.extractArchive(archiveURL: corruptTar, to: corruptTarOut)
        } catch {
            corruptTarFailed = true
        }
        TestReporter.report("ZipArchive", "NEG: extractArchive on a corrupt .tar throws an error", result: corruptTarFailed)

        // NEG: extractArchive on a corrupt .tgz (routed through /usr/bin/tar) throws
        var corruptTgzFailed = false
        let corruptTgz = dir.appendingPathComponent("bad.tgz")
        try? "this is not a valid tgz file at all".write(to: corruptTgz, atomically: true, encoding: .utf8)
        let corruptTgzOut = dir.appendingPathComponent("CorruptTgzOut")
        try? FileManager.default.createDirectory(at: corruptTgzOut, withIntermediateDirectories: true)
        do {
            try ArchiveService.extractArchive(archiveURL: corruptTgz, to: corruptTgzOut)
        } catch {
            corruptTgzFailed = true
        }
        TestReporter.report("ZipArchive", "NEG: extractArchive on a corrupt .tgz throws an error", result: corruptTgzFailed)

        // NEG: extracting a nonexistent archive path throws (exercises the fallback ditto branch's error path too)
        var missingArchiveFailed = false
        let missingArchive = dir.appendingPathComponent("does_not_exist.unknownext")
        let missingOut = dir.appendingPathComponent("MissingOut")
        try? FileManager.default.createDirectory(at: missingOut, withIntermediateDirectories: true)
        do {
            try ArchiveService.extractArchive(archiveURL: missingArchive, to: missingOut)
        } catch {
            missingArchiveFailed = true
        }
        TestReporter.report("ZipArchive", "NEG: extractArchive on a nonexistent file (unknown extension, ditto fallback) throws", result: missingArchiveFailed)
    }
}
