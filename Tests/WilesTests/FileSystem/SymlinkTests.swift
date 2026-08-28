import Foundation
@testable import Wiles

@MainActor
public struct SymlinkTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let targetFile = tempDir.appendingPathComponent("origin.txt")
        try? "Original Content".write(to: targetFile, atomically: true, encoding: .utf8)

        runBasicSymlinkCoverage(tempDir: tempDir, targetFile: targetFile)
        runSymlinkModeIdentifiableCoverage()
        runSameFolderSameNameRegressionCoverage()

        try? FileManager.default.removeItem(at: tempDir)
    }

    // NEG (data-loss regression): createSymlink's "remove existing destination before creating
    // the symlink" branch used to be unconditional — if the caller creates a symlink in the same
    // folder as its own target, using the target's own filename as the symlink name, destinationURL
    // resolves to the exact same path as targetURL. The old code then did
    // `removeItem(at: destinationURL)` — permanently deleting the real source file — before calling
    // `createSymbolicLink`, which then failed anyway because the target no longer existed. This
    // must be a safe abort instead: the source file must still exist afterward, with its original
    // contents intact, and a clear error must be thrown.
    private static func runSameFolderSameNameRegressionCoverage() {
        let regressionDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: regressionDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: regressionDir) }

        let sourceFile = regressionDir.appendingPathComponent("dont_delete_me.txt")
        let originalContent = "precious user data \(UUID().uuidString)"
        try? originalContent.write(to: sourceFile, atomically: true, encoding: .utf8)

        var threwError = false
        do {
            _ = try SymlinkService.createSymlink(
                targetURL: sourceFile,
                destinationFolder: regressionDir,
                symlinkName: sourceFile.lastPathComponent,
                mode: .absolute)
        } catch {
            threwError = true
        }

        let stillExists = FileManager.default.fileExists(atPath: sourceFile.path)
        let contentIntact = (try? String(contentsOf: sourceFile)) == originalContent
        let stillARegularFile = (try? FileManager.default.destinationOfSymbolicLink(atPath: sourceFile.path)) == nil
        TestReporter.report(
            "SymlinkService",
            "NEG: createSymlink whose destination resolves to the same path as its own target never deletes the source (regression: used to permanently destroy it)",
            result: threwError && stillExists && contentIntact && stillARegularFile)
    }

    // POS/NEG: SymlinkMode.id (Identifiable conformance) returns the raw value for both cases.
    private static func runSymlinkModeIdentifiableCoverage() {
        TestReporter.report("SymlinkService", "POS: SymlinkMode.absolute.id returns its rawValue", result: SymlinkMode.absolute.id == "Absolute")
        let relativeIdIsDistinct = SymlinkMode.relative.id == "Relative" && SymlinkMode.relative.id != SymlinkMode.absolute.id
        TestReporter.report("SymlinkService", "NEG: SymlinkMode.relative.id is not the .absolute rawValue", result: relativeIdIsDistinct)
    }

    private static func runBasicSymlinkCoverage(tempDir: URL, targetFile: URL) {
        // Positive: Absolute Symlink
        let linkURL = try? SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: "origin_link.txt", mode: .absolute)
        let symlinkPos = linkURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        TestReporter.report("SymlinkService", "POS: createSymlink (.absolute)", result: symlinkPos)

        // Negative: Empty Symlink Name Falls Back to Default
        let defaultLink = try? SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: "   ", mode: .absolute)
        TestReporter.report(
            "SymlinkService",
            "NEG: Empty symlink name auto-generates default link name",
            result: defaultLink?.lastPathComponent.contains("link") ?? false)

        // POS: Relative symlink resolves back to the same target
        let relativeLinkURL = try? SymlinkService.createSymlink(
            targetURL: targetFile,
            destinationFolder: tempDir,
            symlinkName: "origin_relative_link.txt",
            mode: .relative)
        var relativeResolvesCorrectly = false
        if let link = relativeLinkURL, let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) {
            let resolvedURL = tempDir.standardizedFileURL.appendingPathComponent(resolved).standardizedFileURL
            relativeResolvesCorrectly = resolvedURL.path == targetFile.standardizedFileURL.path
        }
        TestReporter.report("SymlinkService", "POS: createSymlink (.relative) resolves back to the original target", result: relativeResolvesCorrectly)

        // NEG (H4 regression): creating a symlink at a name that already exists must throw
        // `destinationExists` and NOT delete/replace what's there — the old code did an unconditional
        // `removeItem` first, so a real file sitting at that name was permanently destroyed even
        // when the subsequent link creation then failed.
        let occupiedName = "already_here.txt"
        let occupied = tempDir.appendingPathComponent(occupiedName)
        let occupantContent = "do not delete \(UUID().uuidString)"
        try? occupantContent.write(to: occupied, atomically: true, encoding: .utf8)
        var threwDestinationExists = false
        do {
            _ = try SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: occupiedName, mode: .absolute)
        } catch let error as WilesError {
            if case .destinationExists = error {
                threwDestinationExists = true
            }
        } catch { }
        let occupantIntact = (try? String(contentsOf: occupied)) == occupantContent
        let occupantStillRegularFile = (try? FileManager.default.destinationOfSymbolicLink(atPath: occupied.path)) == nil
        TestReporter.report(
            "SymlinkService",
            "NEG: createSymlink onto an existing name throws destinationExists and leaves that item untouched",
            result: threwDestinationExists && occupantIntact && occupantStillRegularFile)

        runAdvancedSymlinkCoverage(tempDir: tempDir, targetFile: targetFile, linkURL: linkURL)
    }

    private static func runAdvancedSymlinkCoverage(tempDir: URL, targetFile: URL, linkURL: URL?) {
        // POS: Creating a symlink to a nonexistent target succeeds and produces a dangling/broken link
        let missingTarget = tempDir.appendingPathComponent("does_not_exist.txt")
        let danglingLink = try? SymlinkService.createSymlink(
            targetURL: missingTarget,
            destinationFolder: tempDir,
            symlinkName: "dangling_link.txt",
            mode: .absolute)
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
        let outsideRelativeLink = try? SymlinkService.createSymlink(
            targetURL: outsideTarget,
            destinationFolder: nestedDestDir,
            symlinkName: "outside_relative_link.txt",
            mode: .relative)
        var outsideRelativeResolves = false
        var outsideRelativeUsesDotDot = false
        if let link = outsideRelativeLink, let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) {
            outsideRelativeUsesDotDot = resolved.hasPrefix("..")
            let resolvedURL = nestedDestDir.standardizedFileURL.appendingPathComponent(resolved).standardizedFileURL
            outsideRelativeResolves = resolvedURL.path == outsideTarget.standardizedFileURL.path
        }
        TestReporter.report(
            "SymlinkService",
            "POS: relative symlink to a target outside the destination folder uses '..' and resolves correctly",
            result: outsideRelativeResolves && outsideRelativeUsesDotDot)

        // POS: Absolute symlink creation stores an absolute path, not a relative one
        let absoluteLinkStoresFullPath: Bool = if let link = linkURL, let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) {
            resolved == targetFile.path
        } else {
            false
        }
        TestReporter.report("SymlinkService", "POS: absolute symlink stores the full absolute destination path", result: absoluteLinkStoresFullPath)
    }
}
