@testable import Wiles
import Foundation

@MainActor
public struct SymlinkTests {
    public static func run() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let targetFile = tempDir.appendingPathComponent("origin.txt")
        try? "Original Content".write(to: targetFile, atomically: true, encoding: .utf8)

        // Positive: Absolute Symlink
        let linkURL = try? SymlinkService.createSymlink(
            targetURL: targetFile,
            destinationFolder: tempDir,
            symlinkName: "origin_link.txt",
            mode: .absolute
        )
        let symlinkPos = linkURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        TestReporter.report("SymlinkService", "POS: createSymlink (.absolute)", result: symlinkPos)

        // Negative: Empty Symlink Name Falls Back to Default
        let defaultLink = try? SymlinkService.createSymlink(
            targetURL: targetFile,
            destinationFolder: tempDir,
            symlinkName: "   ",
            mode: .absolute
        )
        TestReporter.report("SymlinkService", "NEG: Empty symlink name auto-generates default link name", result: defaultLink?.lastPathComponent.contains("link") == true)

        // POS: Relative symlink resolves back to the same target
        let relativeLinkURL = try? SymlinkService.createSymlink(
            targetURL: targetFile,
            destinationFolder: tempDir,
            symlinkName: "origin_relative_link.txt",
            mode: .relative
        )
        var relativeResolvesCorrectly = false
        if let link = relativeLinkURL, let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) {
            let resolvedURL = URL(fileURLWithPath: resolved, relativeTo: tempDir.standardizedFileURL).standardizedFileURL
            relativeResolvesCorrectly = resolvedURL.path == targetFile.standardizedFileURL.path
        }
        TestReporter.report("SymlinkService", "POS: createSymlink (.relative) resolves back to the original target", result: relativeResolvesCorrectly)

        // POS: Creating a symlink at a path that already has one overwrites it instead of throwing
        let overwriteName = "overwrite_link.txt"
        let firstLink = try? SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: overwriteName, mode: .absolute)
        let secondLink = try? SymlinkService.createSymlink(targetURL: targetFile, destinationFolder: tempDir, symlinkName: overwriteName, mode: .absolute)
        TestReporter.report("SymlinkService", "POS: creating a symlink at an existing path overwrites it instead of throwing", result: firstLink != nil && secondLink != nil && FileManager.default.fileExists(atPath: secondLink!.path))

        try? FileManager.default.removeItem(at: tempDir)
    }
}
