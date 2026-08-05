@testable import Wiles
import Foundation

@MainActor
public struct SymlinkTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let targetFile = tempDir.appendingPathComponent("origin.txt")
        try? "Original Content".write(to: targetFile, atomically: true, encoding: .utf8)

        runBasicSymlinkCoverage(tempDir: tempDir, targetFile: targetFile)

        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func runBasicSymlinkCoverage(tempDir: URL, targetFile: URL) {
        // Positive: Absolute Symlink
        let linkURL = try? SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: "origin_link.txt", mode: .absolute)
        let symlinkPos = linkURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        TestReporter.report("SymlinkService", "POS: createSymlink (.absolute)", result: symlinkPos)

        // Negative: Empty Symlink Name Falls Back to Default
        let defaultLink = try? SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: "   ", mode: .absolute)
        TestReporter.report("SymlinkService", "NEG: Empty symlink name auto-generates default link name", result: defaultLink?.lastPathComponent.contains("link") == true)

        // POS: Relative symlink resolves back to the same target
        let relativeLinkURL = try? SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: "origin_relative_link.txt", mode: .relative)
        var relativeResolvesCorrectly = false
        if let link = relativeLinkURL, let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) {
            let resolvedURL = tempDir.standardizedFileURL.appendingPathComponent(resolved).standardizedFileURL
            relativeResolvesCorrectly = resolvedURL.path == targetFile.standardizedFileURL.path
        }
        TestReporter.report("SymlinkService", "POS: createSymlink (.relative) resolves back to the original target", result: relativeResolvesCorrectly)

        // POS: Creating a symlink at a path that already has one overwrites it instead of throwing
        let overwriteName = "overwrite_link.txt"
        let firstLink = try? SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: overwriteName, mode: .absolute)
        let secondLink = try? SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: overwriteName, mode: .absolute)
        let overwriteSucceeded: Bool
        if let secondLink, firstLink != nil {
            overwriteSucceeded = FileManager.default.fileExists(atPath: secondLink.path)
        } else {
            overwriteSucceeded = false
        }
        TestReporter.report(
            "SymlinkService",
            "POS: creating a symlink at an existing path overwrites it instead of throwing",
            result: overwriteSucceeded
        )

        runAdvancedSymlinkCoverage(tempDir: tempDir, targetFile: targetFile, linkURL: linkURL)
    }

    private static func runAdvancedSymlinkCoverage(tempDir: URL, targetFile: URL, linkURL: URL?) {
        // POS: Creating a symlink to a nonexistent target succeeds and produces a dangling/broken link
        let missingTarget = tempDir.appendingPathComponent("does_not_exist.txt")
        let danglingLink = try? SymlinkService.createSymlink(targetURL: missingTarget, destinationFolder: tempDir, symlinkName: "dangling_link.txt", mode: .absolute)
        var danglingIsBroken = false
        if let link = danglingLink {
            let existsAsSymlink = (try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) != nil
            let targetResolves = FileManager.default.fileExists(atPath: link.path)
            danglingIsBroken = existsAsSymlink && !targetResolves
        }
        TestReporter.report("SymlinkService", "POS: createSymlink to a nonexistent target creates a dangling symlink", result: danglingIsBroken)

        // POS: Symlink-to-symlink chain resolves through multiple hops to the original file
        let chainLinkA = try? SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: "chain_a.txt", mode: .absolute)
        var chainResolves = false
        if let linkA = chainLinkA {
            let chainLinkB = try? SymlinkService.createSymlink(targetURL: linkA, destinationFolder: tempDir, symlinkName: "chain_b.txt", mode: .absolute)
            if let linkB = chainLinkB {
                let resolvedPath = (try? FileManager.default.destinationOfSymbolicLink(atPath: linkB.path)).flatMap { intermediate -> String? in
                    try? FileManager.default.destinationOfSymbolicLink(atPath: intermediate)
                }
                let finalReadable = (try? String(contentsOf: linkB, encoding: .utf8)) == "Original Content"
                chainResolves = resolvedPath == targetFile.path && finalReadable
            }
        }
        TestReporter.report("SymlinkService", "POS: chained symlink-to-symlink resolves back to the original file", result: chainResolves)

        runRelativeOutsideAndAbsoluteSymlinkCoverage(tempDir: tempDir, targetFile: targetFile, linkURL: linkURL)
    }

    private static func runRelativeOutsideAndAbsoluteSymlinkCoverage(tempDir: URL, targetFile: URL, linkURL: URL?) {
        // POS: Relative symlink to a target outside the destination folder computes correct ".." components
        let siblingDir = tempDir.appendingPathComponent("sibling")
        let nestedDestDir = tempDir.appendingPathComponent("nested/dest")
        try? FileManager.default.createDirectory(at: siblingDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: nestedDestDir, withIntermediateDirectories: true)
        let outsideTarget = siblingDir.appendingPathComponent("outside.txt")
        try? "Outside Content".write(to: outsideTarget, atomically: true, encoding: .utf8)
        let outsideRelativeLink = try? SymlinkService.createSymlink(targetURL: outsideTarget, destinationFolder: nestedDestDir, symlinkName: "outside_relative_link.txt",
            mode: .relative)
        var outsideRelativeResolves = false
        var outsideRelativeUsesDotDot = false
        if let link = outsideRelativeLink, let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) {
            outsideRelativeUsesDotDot = resolved.hasPrefix("..")
            let resolvedURL = nestedDestDir.standardizedFileURL.appendingPathComponent(resolved).standardizedFileURL
            outsideRelativeResolves = resolvedURL.path == outsideTarget.standardizedFileURL.path
        }
        TestReporter.report("SymlinkService", "POS: relative symlink to a target outside the destination folder uses '..' and resolves correctly",
            result: outsideRelativeResolves && outsideRelativeUsesDotDot)

        // POS: Absolute symlink creation stores an absolute path, not a relative one
        let absoluteLinkStoresFullPath: Bool
        if let link = linkURL, let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) {
            absoluteLinkStoresFullPath = resolved == targetFile.path
        } else {
            absoluteLinkStoresFullPath = false
        }
        TestReporter.report("SymlinkService", "POS: absolute symlink stores the full absolute destination path", result: absoluteLinkStoresFullPath)
    }
}
