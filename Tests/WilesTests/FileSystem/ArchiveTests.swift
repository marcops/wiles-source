@testable import Wiles
import Foundation

@MainActor
public struct ArchiveTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        runIsArchiveAndMultiFileCoverage(tempDir: tempDir)
        runCollisionAndPasswordCoverage()
        runRoundTripCoverage(tempDir: tempDir)

        runPasswordExtractionTests()
        runTarExtractionTests()
        runIsArchiveEdgeCaseTests()
        runExtractZIPWrapperTests()
        runCorruptArchiveErrorPathTests()
        runSourcesOutsideDestinationTests()
        runFolderStructurePreservationTests()
    }

    /// Regression coverage for the -j/no -r fix: compressing a folder that contains a nested
    /// subfolder must preserve that structure in the archive, not flatten everything to the zip
    /// root (the old `zip -j` behavior) or silently drop the nested contents (missing `-r`).
    private static func runFolderStructurePreservationTests() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let folder = dir.appendingPathComponent("TopFolder")
        let nested = folder.appendingPathComponent("Nested")
        try? FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let topFile = folder.appendingPathComponent("top.txt")
        let nestedFile = nested.appendingPathComponent("deep.txt")
        try? "top level".write(to: topFile, atomically: true, encoding: .utf8)
        try? "deeply nested".write(to: nestedFile, atomically: true, encoding: .utf8)

        // A second top-level file alongside the folder exercises the multi-source `zip -r` branch.
        let siblingFile = dir.appendingPathComponent("sibling.txt")
        try? "sibling content".write(to: siblingFile, atomically: true, encoding: .utf8)

        var structurePassed = false
        do {
            try ArchiveService.compressToZIP(urls: [folder, siblingFile], in: dir)
            let zipURL = dir.appendingPathComponent("Archive.zip")
            let out = dir.appendingPathComponent("StructureOut")
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            try ArchiveService.extractArchive(archiveURL: zipURL, to: out)

            let extractedNested = try? String(contentsOf: out.appendingPathComponent("TopFolder/Nested/deep.txt"), encoding: .utf8)
            let extractedTop = try? String(contentsOf: out.appendingPathComponent("TopFolder/top.txt"), encoding: .utf8)
            let extractedSibling = try? String(contentsOf: out.appendingPathComponent("sibling.txt"), encoding: .utf8)
            structurePassed = extractedNested == "deeply nested" && extractedTop == "top level" && extractedSibling == "sibling content"
        } catch {
            print("Folder structure compress error: \(error)")
        }
        TestReporter.report(
            "ZipArchive", "POS: compressToZIP preserves a folder's nested subfolder structure instead of flattening it (-j/-r fix)",
            result: structurePassed
        )
    }

    private static func runIsArchiveAndMultiFileCoverage(tempDir: URL) {
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
    }

    private static func runCollisionAndPasswordCoverage() {
        // POS: name collision appends " 2.zip" counter
        let collideDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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
        let pwdDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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
    }

    private static func runRoundTripCoverage(tempDir: URL) {
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

    /// Regression coverage for the -j/absolute-path fix: source files outside the destination folder must still be found and packed correctly.
    /// Covers both the plain multi-file `zip` branch and the password `zip -P` branch, which use absolute source paths.
    private static func runSourcesOutsideDestinationTests() {
        let sourceDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let destDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: sourceDir)
            try? FileManager.default.removeItem(at: destDir)
        }

        let outsideA = sourceDir.appendingPathComponent("outsideA.txt")
        let outsideB = sourceDir.appendingPathComponent("outsideB.txt")
        try? "Outside A".write(to: outsideA, atomically: true, encoding: .utf8)
        try? "Outside B".write(to: outsideB, atomically: true, encoding: .utf8)

        // POS: multi-file compressToZIP with sources outside the destination folder (exercises the plain `zip -j <dest> <abs paths...>` branch).
        var multiOutsidePassed = false
        do {
            try ArchiveService.compressToZIP(urls: [outsideA, outsideB], in: destDir)
            let zipURL = destDir.appendingPathComponent("Archive.zip")
            let out = destDir.appendingPathComponent("MultiOutsideOut")
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            try ArchiveService.extractArchive(archiveURL: zipURL, to: out)
            let contentA = try? String(contentsOf: out.appendingPathComponent("outsideA.txt"), encoding: .utf8)
            let contentB = try? String(contentsOf: out.appendingPathComponent("outsideB.txt"), encoding: .utf8)
            multiOutsidePassed = contentA == "Outside A" && contentB == "Outside B"
        } catch {
            print("Multi outside-destination compress error: \(error)")
        }
        TestReporter.report("ZipArchive", "POS: compressToZIP with multiple sources outside destination folder packs and extracts both files (-j absolute path fix)",
            result: multiOutsidePassed)

        runPasswordOutsideDestinationTest(destDir: destDir)
    }

    private static func runPasswordOutsideDestinationTest(destDir: URL) {
        // POS: password-protected compressToZIP with sources outside the destination folder
        // (exercises the `zip -j -P <pwd> <dest> <abs paths...>` branch).
        let pwdSourceDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: pwdSourceDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pwdSourceDir) }
        let pwdOutsideFile = pwdSourceDir.appendingPathComponent("pwdOutside.txt")
        try? "Outside secret".write(to: pwdOutsideFile, atomically: true, encoding: .utf8)

        var pwdOutsidePassed = false
        do {
            try ArchiveService.compressToZIP(urls: [pwdOutsideFile], in: destDir, password: "hunter2outside")
            let zipURL = destDir.appendingPathComponent("pwdOutside.zip")
            let out = destDir.appendingPathComponent("PwdOutsideOut")
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-P", "hunter2outside", "-o", zipURL.path, "-d", out.path]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let content = try? String(contentsOf: out.appendingPathComponent("pwdOutside.txt"), encoding: .utf8)
                pwdOutsidePassed = content == "Outside secret"
            }
        } catch {
            print("Password outside-destination compress error: \(error)")
        }
        TestReporter.report("ZipArchive", "POS: compressToZIP with password and source outside destination folder packs and decrypts correctly (-j absolute path fix)",
            result: pwdOutsidePassed)
    }

    private static func runPasswordExtractionTests() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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

        runCorrectPasswordAndDittoCoverage(dir: dir, pwdZip: pwdZip)
    }

    private static func runCorrectPasswordAndDittoCoverage(dir: URL, pwdZip: URL) {
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
}
