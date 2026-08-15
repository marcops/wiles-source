import Foundation
@testable import Wiles

extension ArchiveTests {
    static func runTarExtractionTests() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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

        runTgzExtractionTest(dir: dir)
    }

    private static func runTgzExtractionTest(dir: URL) {
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

        runTarGzExtractionTest(dir: dir)
    }

    private static func runTarGzExtractionTest(dir: URL) {
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
        TestReporter.report(
            "ZipArchive",
            "POS: extractArchive extracts a .tar.gz (name-suffix, non-.tgz extension) via /usr/bin/tar",
            result: tarGzCreated && tarGzExtractPassed)
    }

    static func runIsArchiveEdgeCaseTests() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

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

    static func runExtractZIPWrapperTests() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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

    static func runCorruptArchiveErrorPathTests() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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
